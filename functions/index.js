const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { OpenAI } = require('openai');

// Load environment variables from .env file
require('dotenv').config();

admin.initializeApp();

// Helper function to get OpenAI client
function getOpenAI() {
  // Try environment variable first, then fall back to functions.config()
  const apiKey = process.env.OPENAI_API_KEY || (functions.config().openai && functions.config().openai.key);
  
  if (!apiKey) {
    console.error('❌ OpenAI API key not found! Set OPENAI_API_KEY environment variable.');
    throw new Error('OpenAI API key not configured');
  }
  
  return new OpenAI({
    apiKey: apiKey
  });
}

// ============================================
// AGENT DEFINITIONS
// ============================================

const SUMMARIZER_AGENT = {
  name: "ThreadSummarizer",
  model: "gpt-4",
  instructions: `You are an expert at summarizing remote team conversations.
Your goal is to help busy professionals quickly understand what happened in a conversation.

Focus on:
- Key decisions made
- Action items assigned
- Important blockers or risks
- Next steps

Format your summary as:
- 3-5 concise bullet points
- Each point should be actionable and specific
- Prioritize the most important information
- Use clear, professional language

Example output:
• Decided to launch new feature on March 15th
• Sarah will handle the UI design by end of week
• Blocker: Waiting on API approval from security team
• Next sync scheduled for Friday 2pm`
};

const ACTION_ITEM_AGENT = {
  name: "ActionItemExtractor",
  model: "gpt-4",
  instructions: `You are an expert at extracting action items from team conversations.

For each action item, identify:
- The specific task to be done
- Who is responsible (if mentioned)
- When it's due (if mentioned)
- Priority level (high/medium/low)

Return results in JSON format like:
{
  "actionItems": [
    {
      "task": "Review pull request #123",
      "assignee": "Mike",
      "deadline": "2024-03-15",
      "priority": "high",
      "context": "Needs review before deploy"
    }
  ]
}

Rules:
- Only extract clear, actionable tasks
- If assignee is unclear, set to null
- If deadline is unclear, set to null
- Infer priority from urgency words (ASAP, urgent = high)
- Include brief context for each item`
};

const PRIORITY_DETECTOR_AGENT = {
  name: "PriorityDetector",
  model: "gpt-4",
  instructions: `You analyze messages to detect urgency and priority level.

Return a priority score and explanation in JSON:
{
  "priority": "high" | "medium" | "low",
  "score": 0-100,
  "reason": "Brief explanation",
  "urgencyIndicators": ["ASAP", "urgent", "deadline"]
}

High priority indicators:
- Words like: URGENT, ASAP, CRITICAL, BLOCKER, EMERGENCY
- Mentions of imminent deadlines
- Security issues or bugs in production
- Direct requests from leadership
- Impact on customers

Medium priority:
- Important but not time-sensitive
- General team coordination
- Routine updates with some importance

Low priority:
- FYI messages
- Social chat
- Non-urgent updates`
};

const DECISION_TRACKER_AGENT = {
  name: "DecisionTracker",
  model: "gpt-4",
  instructions: `You identify and track decisions made in team conversations.

A decision is when the team agrees on a course of action, like:
- "Let's go with option A"
- "Approved"
- "We'll use Firebase for this"
- "Decision: Launch on Friday"

Return JSON format:
{
  "decisions": [
    {
      "decision": "Clear statement of what was decided",
      "topic": "What it's about",
      "participantsInvolved": ["Name1", "Name2"],
      "timestamp": "When it was decided",
      "confidence": "high" | "medium" | "low"
    }
  ]
}

Rules:
- Only extract clear decisions, not proposals
- Include context about what was decided
- Note confidence level (was it unanimous? tentative?)
- Track who was involved in the decision`
};

const SMART_SEARCH_AGENT = {
  name: "SmartSearch",
  model: "gpt-4",
  instructions: `You help users find information in their conversation history using semantic understanding.

Given a search query, you:
1. Understand the intent behind the query
2. Find the most relevant messages
3. Provide context around the findings

Return JSON format:
{
  "results": [
    {
      "messageId": "id",
      "relevanceScore": 0-100,
      "snippet": "Relevant part of the message",
      "context": "Why this is relevant to the query",
      "category": "decision" | "action_item" | "discussion" | "general"
    }
  ],
  "summary": "Brief summary of what was found"
}

Handle queries like:
- "When did we decide on pricing?"
- "What are Sarah's tasks?"
- "Find messages about the database migration"
- "Any blockers mentioned last week?"`
};

// ============================================
// HELPER FUNCTIONS
// ============================================

async function getConversationMessages(conversationId, limit) {
  const messagesSnapshot = await admin.firestore()
    .collection('conversations')
    .doc(conversationId)
    .collection('messages')
    .orderBy('timestamp', 'desc')
    .limit(limit || 100)
    .get();
  
  return messagesSnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  })).reverse();
}

function formatMessagesForAI(messages) {
  return messages.map(msg => {
    let date = new Date();
    if (msg.timestamp && msg.timestamp.toDate) {
      date = msg.timestamp.toDate();
    } else if (msg.timestamp instanceof Date) {
      date = msg.timestamp;
    } else if (typeof msg.timestamp === 'string') {
      date = new Date(msg.timestamp);
    }
    
    const senderName = msg.senderName || msg.sender || 'Unknown';
    const text = msg.content || msg.text || '';  // Check both 'content' and 'text'
    
    return `[${date.toLocaleString()}] ${senderName}: ${text}`;
  }).join('\n');
}

async function callAgent(agent, prompt) {
  const openai = getOpenAI(); // Get OpenAI client here
  
  const systemMessage = {
    role: "system",
    content: agent.instructions
  };
  
  const userMessage = {
    role: "user",
    content: prompt
  };
  
  const response = await openai.chat.completions.create({
    model: agent.model,
    messages: [systemMessage, userMessage],
    temperature: 0.3,
    max_tokens: 1500
  });
  
  return response.choices[0].message.content;
}

// ============================================
// CLOUD FUNCTIONS
// ============================================

exports.summarizeThread = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    const conversationId = data.conversationId;
    const messageLimit = data.messageLimit;
    
    if (!conversationId) {
      throw new functions.https.HttpsError('invalid-argument', 'conversationId is required');
    }
    
    const messages = await getConversationMessages(conversationId, messageLimit || 100);
    
    if (messages.length === 0) {
      return {
        summary: ['No messages in this conversation yet.'],
        messageCount: 0
      };
    }
    
    const conversationText = formatMessagesForAI(messages);
    const prompt = 'Analyze this team conversation and provide a concise summary:\n\n' + conversationText;
    const summaryText = await callAgent(SUMMARIZER_AGENT, prompt);
    
    const summaryPoints = summaryText
      .split('\n')
      .filter(line => {
        const trimmed = line.trim();
        return trimmed.startsWith('•') || trimmed.startsWith('-');
      })
      .map(line => line.replace(/^[•\-]\s*/, '').trim())
      .filter(point => point.length > 0);
    
    await admin.firestore()
      .collection('conversations')
      .doc(conversationId)
      .collection('aiInsights')
      .add({
        type: 'summary',
        content: summaryPoints,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        messageCount: messages.length
      });
    
    return {
      summary: summaryPoints,
      messageCount: messages.length,
      generatedAt: new Date().toISOString()
    };
    
  } catch (error) {
    console.error('Error in summarizeThread:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

exports.extractActionItems = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    const conversationId = data.conversationId;
    const messageLimit = data.messageLimit;
    
    if (!conversationId) {
      throw new functions.https.HttpsError('invalid-argument', 'conversationId is required');
    }
    
    const messages = await getConversationMessages(conversationId, messageLimit || 100);
    
    if (messages.length === 0) {
      return { actionItems: [] };
    }
    
    const conversationText = formatMessagesForAI(messages);
    const prompt = 'Extract all action items from this conversation. Return as JSON:\n\n' + conversationText;
    const responseText = await callAgent(ACTION_ITEM_AGENT, prompt);
    
    let actionItems = [];
    try {
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        actionItems = parsed.actionItems || [];
      }
    } catch (parseError) {
      console.error('Error parsing action items JSON:', parseError);
      actionItems = [];
    }
    
    if (actionItems.length > 0) {
      await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('aiInsights')
        .add({
          type: 'actionItems',
          content: actionItems,
          generatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
    }
    
    return {
      actionItems: actionItems,
      generatedAt: new Date().toISOString()
    };
    
  } catch (error) {
    console.error('Error in extractActionItems:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

exports.detectPriority = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    const messageText = data.messageText;
    const conversationContext = data.conversationContext;
    
    if (!messageText) {
      throw new functions.https.HttpsError('invalid-argument', 'messageText is required');
    }
    
    let prompt = 'Analyze this message for urgency and priority:\n\nMessage: "' + messageText + '"';
    if (conversationContext) {
      prompt = prompt + '\n\nContext: ' + conversationContext;
    }
    
    const responseText = await callAgent(PRIORITY_DETECTOR_AGENT, prompt);
    
    let priorityData = { priority: 'low', score: 0 };
    try {
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        priorityData = JSON.parse(jsonMatch[0]);
      }
    } catch (parseError) {
      console.error('Error parsing priority JSON:', parseError);
    }
    
    return priorityData;
    
  } catch (error) {
    console.error('Error in detectPriority:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

exports.trackDecisions = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    const conversationId = data.conversationId;
    const messageLimit = data.messageLimit;
    
    if (!conversationId) {
      throw new functions.https.HttpsError('invalid-argument', 'conversationId is required');
    }
    
    const messages = await getConversationMessages(conversationId, messageLimit || 100);
    
    if (messages.length === 0) {
      return { decisions: [] };
    }
    
    const conversationText = formatMessagesForAI(messages);
    const prompt = 'Identify all decisions made in this conversation. Return as JSON:\n\n' + conversationText;
    const responseText = await callAgent(DECISION_TRACKER_AGENT, prompt);
    
    let decisions = [];
    try {
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        decisions = parsed.decisions || [];
      }
    } catch (parseError) {
      console.error('Error parsing decisions JSON:', parseError);
    }
    
    if (decisions.length > 0) {
      await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('aiInsights')
        .add({
          type: 'decisions',
          content: decisions,
          generatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
    }
    
    return {
      decisions: decisions,
      generatedAt: new Date().toISOString()
    };
    
  } catch (error) {
    console.error('Error in trackDecisions:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

exports.smartSearch = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    const query = data.query;
    const conversationId = data.conversationId;
    const messageLimit = data.messageLimit;
    
    if (!query) {
      throw new functions.https.HttpsError('invalid-argument', 'query is required');
    }
    
    const messages = await getConversationMessages(conversationId, messageLimit || 200);
    
    if (messages.length === 0) {
      return { results: [], summary: 'No messages to search.' };
    }
    
    const conversationText = formatMessagesForAI(messages);
    const prompt = 'Search query: "' + query + '"\n\nFind relevant information in these messages and return as JSON:\n\n' + conversationText;
    const responseText = await callAgent(SMART_SEARCH_AGENT, prompt);
    
    let searchResults = { results: [], summary: '' };
    try {
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        searchResults = JSON.parse(jsonMatch[0]);
      }
    } catch (parseError) {
      console.error('Error parsing search JSON:', parseError);
    }
    
    return searchResults;
    
  } catch (error) {
    console.error('Error in smartSearch:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Firestore trigger temporarily disabled
// Will add back with v2 API syntax later