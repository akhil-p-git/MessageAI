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
// ENHANCED AGENT DEFINITIONS
// ============================================

const SUMMARIZER_AGENT = {
  name: "ThreadSummarizer",
  model: "gpt-4-turbo-preview", // Faster model
  instructions: `You are an elite executive assistant specializing in distilling complex team conversations into actionable insights.

CORE MISSION: Transform lengthy discussions into crystal-clear summaries that busy professionals can act on immediately.

ANALYSIS FRAMEWORK:
1. DECISIONS: What was definitively agreed upon?
2. ACTIONS: Who needs to do what by when?
3. BLOCKERS: What's preventing progress?
4. RISKS: What could go wrong?
5. NEXT STEPS: What happens next?

OUTPUT FORMAT:
• Use bullet points starting with emoji indicators:
  ✅ Decisions (what was agreed)
  📋 Action items (who, what, when)
  🚧 Blockers (what's stuck)
  ⚠️ Risks (what to watch)
  ➡️ Next steps (what's coming)

QUALITY STANDARDS:
- Each point must be specific and actionable
- Include names, dates, and concrete details
- Prioritize by business impact
- Maximum 5-7 points total
- Use active voice and present tense
- Highlight urgency when present

CONTEXT AWARENESS:
- Identify conversation patterns (brainstorming, problem-solving, status update)
- Note sentiment shifts (concern, enthusiasm, frustration)
- Flag incomplete discussions or unresolved questions
- Recognize implicit decisions or consensus

EXAMPLE OUTPUT:
✅ Decided to launch MVP on March 15th (unanimous agreement)
📋 Sarah will complete UI mockups by Friday EOD (high priority)
🚧 Blocker: Waiting on security team approval for API access
⚠️ Risk: Timeline is tight if design revisions needed
➡️ Next sync: Monday 10am to review progress

Remember: Your summary should enable someone who missed the conversation to make informed decisions immediately.`
};

const ACTION_ITEM_AGENT = {
  name: "ActionItemExtractor",
  model: "gpt-4-turbo-preview",
  instructions: `Extract action items from conversations. Be VERY INCLUSIVE.

Include any task, question, request, or commitment as an action item.

Return ONLY valid JSON in this format:
{
  "actionItems": [
    {"task": "description", "assignee": "name or null", "priority": "high|medium|low"}
  ]
}

No markdown. No code blocks. Just JSON.`
};

const PRIORITY_DETECTOR_AGENT = {
  name: "PriorityDetector",
  model: "gpt-4-turbo-preview",
  instructions: `You are an expert triage specialist who analyzes messages to determine urgency and priority with exceptional accuracy.

CORE MISSION: Assess message priority using multi-dimensional analysis to ensure critical communications are never missed.

ANALYSIS DIMENSIONS:

1. EXPLICIT URGENCY SIGNALS (Weight: 40%)
   HIGH: URGENT, ASAP, CRITICAL, EMERGENCY, BLOCKER, NOW, IMMEDIATELY
   MEDIUM: soon, important, priority, deadline, time-sensitive
   LOW: FYI, when you can, no rush, eventually

2. BUSINESS IMPACT (Weight: 30%)
   HIGH: Production down, customer-facing issues, revenue impact, security breach
   MEDIUM: Team productivity, project delays, internal tools
   LOW: Nice-to-haves, optimizations, future planning

3. TEMPORAL CONTEXT (Weight: 20%)
   HIGH: Today, within hours, EOD, before meeting
   MEDIUM: This week, by Friday, next sprint
   LOW: Eventually, someday, backlog

4. SENDER AUTHORITY (Weight: 10%)
   HIGH: CEO, direct manager, client, executive
   MEDIUM: Team lead, peer with urgent request
   LOW: General team member, automated notification

PRIORITY LEVELS (DEFAULT TO MEDIUM OR HIGH):

HIGH (Score: 60-100):
- ANY questions or requests
- ANY tasks or commitments
- Deadlines mentioned
- Problems or issues
- Coordination needed
- Decisions to make
- Follow-ups needed

MEDIUM (Score: 20-59):
- Updates and information
- General discussions with some importance
- Planning conversations

LOW (Score: 0-19):
- ONLY pure social chat with zero work relevance
- Pure acknowledgments: "ok", "thanks"

IMPORTANT: If the message has ANY work-related content, it should be MEDIUM or HIGH. Default to score 50+ for most messages.

OUTPUT FORMAT (JSON):
{
  "priority": "high" | "medium" | "low",
  "score": 0-100,
  "confidence": "very_high" | "high" | "medium" | "low",
  "reason": "Clear explanation of priority assessment",
  "urgencyIndicators": ["List of specific words/phrases that indicate urgency"],
  "businessImpact": "Description of potential business impact",
  "recommendedAction": "What the recipient should do",
  "timeframe": "When action is needed",
  "category": "bug" | "feature" | "question" | "update" | "decision" | "blocker" | "social"
}

CONTEXT AWARENESS:
- Consider conversation history if provided
- Recognize escalation patterns (follow-ups increase priority)
- Identify implicit urgency from context
- Factor in time of day (late night messages often urgent)
- Recognize industry-specific urgency terms

SPECIAL CASES:
- Questions from leadership: Automatically medium+
- "Ping" or "Following up": Increases priority
- Multiple exclamation marks: Indicates urgency
- All caps: Strong urgency signal
- Mentions of customers/clients: High priority
- Security/privacy keywords: Critical priority

Remember: Your assessment directly impacts whether someone sees a message in time. Err on the side of higher priority for ambiguous cases.`
};

const DECISION_TRACKER_AGENT = {
  name: "DecisionTracker",
  model: "gpt-4-turbo-preview",
  instructions: `Extract decisions from conversations. Be VERY INCLUSIVE.

Include any agreement, commitment, choice, or plan as a decision.

Return ONLY valid JSON in this format:
{
  "decisions": [
    {"decision": "what was decided", "topic": "subject", "participantsInvolved": ["names"], "confidence": "high|medium|low"}
  ]
}

No markdown. No code blocks. Just JSON.`
};

const SMART_SEARCH_AGENT = {
  name: "SmartSearch",
  model: "gpt-4-turbo-preview",
  instructions: `You are an elite information retrieval specialist with expertise in semantic search and natural language understanding.

CORE MISSION: Help users find exactly what they're looking for in their conversation history using advanced semantic understanding, even when they don't know the exact words.

SEARCH CAPABILITIES:

1. SEMANTIC UNDERSTANDING:
   - Understand intent, not just keywords
   - "Who's handling deployment?" = Find action items about deployment
   - "What did we decide about pricing?" = Find pricing decisions
   - "Any blockers?" = Find messages mentioning obstacles

2. ENTITY RECOGNITION:
   - People: Names, roles, pronouns
   - Dates: "last week", "Friday", "Q1"
   - Topics: Projects, features, technologies
   - Status: "blocked", "done", "pending"

3. CONTEXT AWARENESS:
   - Understand conversation flow
   - Connect related messages
   - Identify cause and effect
   - Recognize follow-ups and references

4. QUERY TYPES:

   FACTUAL: "When did we decide X?"
   - Find specific information
   - Return exact message
   - Include timestamp

   PERSON-FOCUSED: "What are Sarah's tasks?"
   - Filter by person
   - Find all relevant mentions
   - Summarize their commitments

   TOPIC-FOCUSED: "Find messages about database"
   - Semantic topic matching
   - Include related discussions
   - Group by subtopic

   STATUS: "Any blockers mentioned?"
   - Find status indicators
   - Identify problems
   - Show resolution if available

   TEMPORAL: "What happened last week?"
   - Time-based filtering
   - Chronological ordering
   - Highlight key events

RELEVANCE SCORING (0-100):

100: Perfect match
- Exact answer to query
- Direct quote
- Highly specific

80-99: Excellent match
- Strong semantic relevance
- Contains key information
- Very useful

60-79: Good match
- Related to query
- Provides context
- Somewhat useful

40-59: Moderate match
- Tangentially related
- Background information
- May be useful

20-39: Weak match
- Minimal relevance
- Mentioned in passing
- Low utility

0-19: Poor match
- Almost irrelevant
- Should not be returned

OUTPUT FORMAT (JSON):
{
  "results": [
    {
      "messageId": "Unique identifier",
      "relevanceScore": 0-100,
      "snippet": "Most relevant part of the message (50-100 chars)",
      "fullMessage": "Complete message text",
      "context": "Why this is relevant to the query",
      "category": "decision" | "action_item" | "discussion" | "question" | "answer" | "blocker" | "update",
      "sender": "Person who sent the message",
      "timestamp": "When it was sent",
      "relatedMessages": ["IDs of related messages"],
      "highlights": ["Key phrases that match the query"]
    }
  ],
  "summary": "Brief overview of what was found",
  "totalResults": "Number of results",
  "searchInsights": {
    "queryIntent": "What the user is trying to find",
    "suggestedRefinements": ["Ways to narrow the search"],
    "relatedTopics": ["Other topics that might be relevant"]
  }
}

SEARCH STRATEGIES:

1. KEYWORD EXPANSION:
   - "deploy" → deployment, deploying, deployed
   - "bug" → issue, problem, error, broken
   - "meeting" → sync, call, standup, discussion

2. SYNONYM RECOGNITION:
   - "finish" = complete, done, finalize
   - "start" = begin, kick off, initiate
   - "problem" = issue, blocker, challenge

3. ACRONYM HANDLING:
   - Recognize common acronyms (API, UI, DB)
   - Expand when context suggests
   - Match both forms

4. TEMPORAL REASONING:
   - "last week" → Calculate date range
   - "recently" → Last 7 days
   - "Q1" → January-March

5. NEGATION HANDLING:
   - "not decided" → Find open discussions
   - "no blocker" → Find smooth progress
   - "without approval" → Find pending items

RESULT RANKING:

Primary factors:
1. Semantic relevance (40%)
2. Recency (20%)
3. Message importance (20%)
4. Participant authority (10%)
5. Conversation context (10%)

EDGE CASES:

NO RESULTS:
- Suggest query refinements
- Offer related topics
- Explain why nothing matched

TOO MANY RESULTS:
- Return top 10 by relevance
- Suggest filters
- Group by category

AMBIGUOUS QUERY:
- Interpret most likely intent
- Note alternative interpretations
- Ask for clarification if needed

MULTI-PART QUERY:
- "Who decided what about pricing?"
- Break into components
- Find intersection of results

Remember: Your goal is to save users time by finding exactly what they need, even when they can't articulate it perfectly. Be intelligent about understanding intent, not just matching words.`
};

// ============================================
// ENHANCED HELPER FUNCTIONS
// ============================================

// Get conversation messages with smart filtering
async function getConversationMessages(conversationId, limit, options = {}) {
  let query = admin.firestore()
    .collection('conversations')
    .doc(conversationId)
    .collection('messages')
    .orderBy('timestamp', 'desc');
  
  // Apply time filter if provided
  if (options.startDate) {
    query = query.where('timestamp', '>=', options.startDate);
  }
  if (options.endDate) {
    query = query.where('timestamp', '<=', options.endDate);
  }
  
  query = query.limit(limit || 100);
  
  const messagesSnapshot = await query.get();
  
  let messages = messagesSnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  })).reverse();
  
  // Filter by sender if provided
  if (options.sender) {
    messages = messages.filter(msg => 
      msg.senderName && msg.senderName.toLowerCase().includes(options.sender.toLowerCase())
    );
  }
  
  return messages;
}

// Enhanced message formatting with metadata
function formatMessagesForAI(messages, options = {}) {
  const includeMetadata = options.includeMetadata !== false;
  const maxLength = options.maxLength || 10000; // Character limit for context
  
  let formatted = messages.map((msg, index) => {
    let date = new Date();
    if (msg.timestamp && msg.timestamp.toDate) {
      date = msg.timestamp.toDate();
    } else if (msg.timestamp instanceof Date) {
      date = msg.timestamp;
    } else if (typeof msg.timestamp === 'string') {
      date = new Date(msg.timestamp);
    }
    
    const senderName = msg.senderName || msg.sender || 'Unknown';
    const text = msg.content || msg.text || '';
    
    // Add message number for reference
    let formattedMsg = `[${index + 1}] `;
    
    // Add timestamp
    if (includeMetadata) {
      formattedMsg += `[${date.toLocaleString()}] `;
    }
    
    // Add sender and message
    formattedMsg += `${senderName}: ${text}`;
    
    // Add reactions if present
    if (includeMetadata && msg.reactions && Object.keys(msg.reactions).length > 0) {
      const reactionStr = Object.entries(msg.reactions)
        .map(([userId, emoji]) => emoji)
        .join(' ');
      formattedMsg += ` [Reactions: ${reactionStr}]`;
    }
    
    return formattedMsg;
  }).join('\n');
  
  // Truncate if too long, keeping most recent messages
  if (formatted.length > maxLength) {
    const lines = formatted.split('\n');
    let truncated = '';
    let lineCount = 0;
    
    // Take from the end (most recent)
    for (let i = lines.length - 1; i >= 0; i--) {
      if ((truncated.length + lines[i].length) > maxLength) {
        break;
      }
      truncated = lines[i] + '\n' + truncated;
      lineCount++;
    }
    
    formatted = `[Showing ${lineCount} most recent messages]\n\n` + truncated;
  }
  
  return formatted;
}

// Enhanced AI calling with retry logic and streaming
async function callAgent(agent, prompt, options = {}) {
  const openai = getOpenAI();
  const maxRetries = options.maxRetries || 2;
  const temperature = options.temperature !== undefined ? options.temperature : 0.2; // Lower for more consistent results
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
  const systemMessage = {
    role: "system",
    content: agent.instructions
  };
  
  const userMessage = {
    role: "user",
    content: prompt
  };
  
      // Use faster model for better performance
  const response = await openai.chat.completions.create({
    model: agent.model,
    messages: [systemMessage, userMessage],
        temperature: temperature,
        max_tokens: options.maxTokens || 2000,
        response_format: options.jsonMode ? { type: "json_object" } : undefined,
        // Use higher top_p for more diverse responses
        top_p: 0.9,
        // Add frequency penalty to reduce repetition
        frequency_penalty: 0.3,
        presence_penalty: 0.1
  });
  
  return response.choices[0].message.content;
      
    } catch (error) {
      console.error(`Attempt ${attempt + 1} failed:`, error.message);
      
      if (attempt === maxRetries) {
        throw error;
      }
      
      // Exponential backoff
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
    }
  }
}

// Extract JSON from response with better error handling
function extractJSON(text) {
  try {
    // Try to parse the entire response first
    return JSON.parse(text);
  } catch (e) {
    // Look for JSON in code blocks
    const codeBlockMatch = text.match(/```json\n([\s\S]*?)\n```/);
    if (codeBlockMatch) {
      return JSON.parse(codeBlockMatch[1]);
    }
    
    // Look for JSON object
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]);
    }
    
    throw new Error('No valid JSON found in response');
  }
}

// ============================================
// ENHANCED CLOUD FUNCTIONS
// ============================================

exports.summarizeThread = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    const conversationId = data.conversationId;
    const messageLimit = data.messageLimit || 100;
    
    if (!conversationId) {
      throw new functions.https.HttpsError('invalid-argument', 'conversationId is required');
    }
    
    console.log(`📊 Summarizing conversation ${conversationId} (limit: ${messageLimit})`);
    
    const messages = await getConversationMessages(conversationId, messageLimit);
    
    if (messages.length === 0) {
      return {
        summary: ['No messages in this conversation yet.'],
        messageCount: 0
      };
    }
    
    // Format messages with metadata for better context
    const conversationText = formatMessagesForAI(messages, { includeMetadata: true });
    
    // Enhanced prompt with conversation stats
    const prompt = `Analyze this team conversation and provide an executive summary.

Conversation Stats:
- Total messages: ${messages.length}
- Participants: ${[...new Set(messages.map(m => m.senderName || m.sender))].join(', ')}
- Time span: ${messages[0].timestamp ? new Date(messages[0].timestamp.toDate ? messages[0].timestamp.toDate() : messages[0].timestamp).toLocaleDateString() : 'Unknown'} to ${messages[messages.length - 1].timestamp ? new Date(messages[messages.length - 1].timestamp.toDate ? messages[messages.length - 1].timestamp.toDate() : messages[messages.length - 1].timestamp).toLocaleDateString() : 'Unknown'}

Conversation:
${conversationText}

Provide a comprehensive summary following your instructions.`;
    
    const summaryText = await callAgent(SUMMARIZER_AGENT, prompt, { 
      temperature: 0.3,
      maxTokens: 4096
    });
    
    // Parse summary into structured points
    const summaryPoints = summaryText
      .split('\n')
      .filter(line => {
        const trimmed = line.trim();
        return trimmed.startsWith('•') || trimmed.startsWith('-') || trimmed.startsWith('✅') || 
               trimmed.startsWith('📋') || trimmed.startsWith('🚧') || trimmed.startsWith('⚠️') || 
               trimmed.startsWith('➡️');
      })
      .map(line => {
        let cleaned = line.replace(/^[•\-✅📋🚧⚠️➡️]\s*/, '').trim();
        // Remove invalid Unicode that breaks JSON
        cleaned = cleaned.replace(/[\uD800-\uDFFF]/g, '');
        return cleaned;
      })
      .filter(point => point.length > 0);
    
    console.log(`✅ Generated summary with ${summaryPoints.length} points`);
    
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
    const messageLimit = data.messageLimit || 100;
    
    if (!conversationId) {
      throw new functions.https.HttpsError('invalid-argument', 'conversationId is required');
    }
    
    console.log(`📋 Extracting action items from conversation ${conversationId}`);
    
    const messages = await getConversationMessages(conversationId, messageLimit);
    
    if (messages.length === 0) {
      return { actionItems: [] };
    }
    
    const conversationText = formatMessagesForAI(messages, { includeMetadata: true });
    
    const prompt = `Extract action items from this conversation. Include tasks, questions that need answers, problems to solve, and follow-ups.

Conversation:
${conversationText}

Find EVERY task, request, question, or commitment. Include:
- "I'll do X" → task
- "Can you Y?" → task
- "We need to Z" → task
- "Let's follow up" → task
- Problems mentioned → task to fix them

Return JSON with actionItems array. Be inclusive - better to include too many than miss any.`;
    
    const responseText = await callAgent(ACTION_ITEM_AGENT, prompt, { 
      temperature: 0.2,
      maxTokens: 4096,
      jsonMode: true
    });
    
    let actionItems = [];
    try {
      const parsed = extractJSON(responseText);
      actionItems = parsed.actionItems || parsed.items || [];
      
      // Clean invalid Unicode from all string fields
      actionItems = actionItems.map((item, index) => {
        const cleaned = {};
        for (const key in item) {
          if (typeof item[key] === 'string') {
            cleaned[key] = item[key].replace(/[\uD800-\uDFFF]/g, '');
          } else {
            cleaned[key] = item[key];
          }
        }
        return {
          id: `action_${Date.now()}_${index}`,
          ...cleaned,
          extractedAt: new Date().toISOString()
        };
      });
      
    } catch (parseError) {
      console.error('Error parsing action items JSON:', parseError);
      console.log('Raw response:', responseText);
      actionItems = [];
    }
    
    console.log(`✅ Extracted ${actionItems.length} action items`);
    
    return {
      items: actionItems,
      actionItems: actionItems,
      totalCount: actionItems.length,
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
    
    console.log(`⚡ Detecting priority for message: "${messageText.substring(0, 50)}..."`);
    
    let prompt = `Analyze this message for urgency and priority:

Message: "${messageText}"`;
    
    if (conversationContext) {
      prompt += `\n\nRecent conversation context:\n${conversationContext}`;
    }
    
    prompt += '\n\nProvide a detailed priority analysis in JSON format following your instructions.';
    
    const responseText = await callAgent(PRIORITY_DETECTOR_AGENT, prompt, { 
      temperature: 0.1,
      maxTokens: 4096,
      jsonMode: true
    });
    
    let priorityData = { 
      priority: 'medium', 
      score: 50,
      confidence: 'medium',
      reason: 'Unable to determine priority',
      urgencyIndicators: [],
      recommendedAction: 'Review when convenient'
    };
    
    try {
      const parsed = extractJSON(responseText);
      priorityData = {
        ...priorityData,
        ...parsed
      };
    } catch (parseError) {
      console.error('Error parsing priority JSON:', parseError);
      console.log('Raw response:', responseText);
    }
    
    console.log(`✅ Priority detected: ${priorityData.priority} (score: ${priorityData.score})`);
    
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
    const messageLimit = data.messageLimit || 100;
    
    if (!conversationId) {
      throw new functions.https.HttpsError('invalid-argument', 'conversationId is required');
    }
    
    console.log(`🎯 Tracking decisions in conversation ${conversationId}`);
    
    const messages = await getConversationMessages(conversationId, messageLimit);
    
    if (messages.length === 0) {
      return { decisions: [] };
    }
    
    const conversationText = formatMessagesForAI(messages, { includeMetadata: true });
    
    const prompt = `Identify decisions made in this conversation. Include agreements, commitments, and choices.

Conversation:
${conversationText}

Find EVERY decision, agreement, or commitment. Include:
- "Let's do X" → decision
- "Agreed" / "Approved" → decision
- "I'll handle Y" → decision/commitment
- "We're using Z" → decision
- Plans set → decision

Return JSON with decisions array. Be inclusive - better to include too many than miss any.`;
    
    const responseText = await callAgent(DECISION_TRACKER_AGENT, prompt, { 
      temperature: 0.2,
      maxTokens: 4096,
      jsonMode: true
    });
    
    let decisions = [];
    try {
      const parsed = extractJSON(responseText);
        decisions = parsed.decisions || [];
      
      // Clean invalid Unicode from all string fields
      decisions = decisions.map((decision, index) => {
        const cleaned = {};
        for (const key in decision) {
          if (typeof decision[key] === 'string') {
            cleaned[key] = decision[key].replace(/[\uD800-\uDFFF]/g, '');
          } else {
            cleaned[key] = decision[key];
          }
        }
        return {
          id: `decision_${Date.now()}_${index}`,
          ...cleaned,
          extractedAt: new Date().toISOString()
        };
      });
      
    } catch (parseError) {
      console.error('Error parsing decisions JSON:', parseError);
      console.log('Raw response:', responseText);
    }
    
    console.log(`✅ Tracked ${decisions.length} decisions`);
    
    return {
      decisions: decisions,
      totalCount: decisions.length,
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
    const messageLimit = data.messageLimit || 200; // Search more messages by default
    
    if (!query) {
      throw new functions.https.HttpsError('invalid-argument', 'query is required');
    }
    
    console.log(`🔍 Smart search: "${query}" in conversation ${conversationId}`);
    
    const messages = await getConversationMessages(conversationId, messageLimit);
    
    if (messages.length === 0) {
      return { 
        results: [], 
        summary: 'No messages to search.',
        searchInsights: {
          queryIntent: 'Unknown',
          suggestedRefinements: [],
          relatedTopics: []
        }
      };
    }
    
    // Format messages with full metadata for better search
    const conversationText = formatMessagesForAI(messages, { 
      includeMetadata: true,
      maxLength: 15000 // Allow more context for search
    });
    
    const prompt = `Search Query: "${query}"

Find the most relevant information in this conversation. Use semantic understanding to match the query intent.

Conversation (${messages.length} messages):
${conversationText}

Return a comprehensive JSON response following your instructions. Include relevance scores, context, and search insights.`;
    
    const responseText = await callAgent(SMART_SEARCH_AGENT, prompt, { 
      temperature: 0.2,
      maxTokens: 4096,
      jsonMode: true
    });
    
    let searchResults = { 
      results: [], 
      summary: 'No results found',
      searchInsights: {
        queryIntent: 'Unable to determine',
        suggestedRefinements: [],
        relatedTopics: []
      }
    };
    
    try {
      const parsed = extractJSON(responseText);
      searchResults = {
        ...searchResults,
        ...parsed
      };
      
      // Sort results by relevance score
      if (searchResults.results && Array.isArray(searchResults.results)) {
        searchResults.results.sort((a, b) => (b.relevanceScore || 0) - (a.relevanceScore || 0));
        
        // Limit to top 10 results
        searchResults.results = searchResults.results.slice(0, 10);
      }
      
    } catch (parseError) {
      console.error('Error parsing search JSON:', parseError);
      console.log('Raw response:', responseText);
    }
    
    console.log(`✅ Found ${searchResults.results?.length || 0} results`);
    
    return {
      ...searchResults,
      totalResults: searchResults.results?.length || 0,
      generatedAt: new Date().toISOString()
    };
    
  } catch (error) {
    console.error('Error in smartSearch:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Health check endpoint
exports.healthCheck = functions.https.onCall(async (data, context) => {
  try {
    const openai = getOpenAI();
    
    // Simple test call
    const response = await openai.chat.completions.create({
      model: "gpt-4-turbo-preview",
      messages: [
        { role: "user", content: "Say 'OK' if you're working." }
      ],
      max_tokens: 10
    });
    
    return {
      status: 'healthy',
      message: 'All AI agents are operational',
      openaiResponse: response.choices[0].message.content,
      timestamp: new Date().toISOString()
    };
    
  } catch (error) {
    console.error('Health check failed:', error);
    return {
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    };
  }
});

// Block check trigger - auto-reply when blocked user tries to message
exports.checkBlockOnMessage = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const senderID = message.senderID;
    const conversationId = context.params.conversationId;
    
    try {
      // Get conversation to find recipient
      const conversationDoc = await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .get();
      
      const conversation = conversationDoc.data();
      if (!conversation || conversation.isGroup) {
        return; // Only check for 1-on-1 chats
      }
      
      const participantIDs = conversation.participantIDs || [];
      const recipientID = participantIDs.find(id => id !== senderID);
      
      if (!recipientID) return;
      
      // Check if sender is blocked by recipient
      const recipientDoc = await admin.firestore()
        .collection('users')
        .doc(recipientID)
        .get();
      
      const blockedUsers = recipientDoc.data()?.blockedUsers || [];
      
      if (blockedUsers.includes(senderID)) {
        console.log(`🚫 User ${senderID} is blocked by ${recipientID}`);
        
        // Delete the message they just sent
        await snap.ref.delete();
        
        // Send auto-reply from system
        const autoReplyMessage = {
          id: `blocked_${Date.now()}`,
          conversationID: conversationId,
          senderID: 'system',
          content: 'This user has blocked you',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          status: 'sent',
          type: 'text',
          isSystemMessage: true,
          readBy: []
        };
        
        await admin.firestore()
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(autoReplyMessage);
        
        console.log('✅ Sent block notification to sender');
      }
    } catch (error) {
      console.error('Error in block check:', error);
    }
  });
