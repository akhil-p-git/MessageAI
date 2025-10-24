import Foundation
import FirebaseFirestore
import FirebaseAuth

class DiagnosticHelper {
    static func runDiagnostics() {
        print("\n" + String(repeating: "=", count: 60))
        print("🔍 MESSAGEAI DIAGNOSTICS")
        print(String(repeating: "=", count: 60) + "\n")
        
        // Check 1: Firebase Auth
        if let currentUser = Auth.auth().currentUser {
            print("✅ Firebase Auth: WORKING")
            print("   User ID: \(currentUser.uid)")
            print("   Email: \(currentUser.email ?? "N/A")")
            print("   Display Name: \(currentUser.displayName ?? "N/A")")
        } else {
            print("❌ Firebase Auth: NOT LOGGED IN")
            print("   Please sign in to continue diagnostics")
            print(String(repeating: "=", count: 60) + "\n")
            return
        }
        
        // Check 2: Firestore Connection
        let db = Firestore.firestore()
        print("\n📊 Testing Firestore Connection...")
        
        Task {
            do {
                // Try to read users collection
                print("   Testing users collection...")
                let usersSnapshot = try await db.collection("users").limit(to: 1).getDocuments()
                print("   ✅ Users Collection: ACCESSIBLE (\(usersSnapshot.documents.count) docs found)")
                
                // Try to read conversations
                print("   Testing conversations collection...")
                let convsSnapshot = try await db.collection("conversations").limit(to: 1).getDocuments()
                print("   ✅ Conversations Collection: ACCESSIBLE (\(convsSnapshot.documents.count) docs found)")
                
                // Try to write test document
                print("   Testing write permissions...")
                let testRef = db.collection("_diagnostics").document("test_\(UUID().uuidString)")
                try await testRef.setData([
                    "timestamp": Timestamp(date: Date()),
                    "test": true,
                    "user": Auth.auth().currentUser?.uid ?? "unknown"
                ])
                print("   ✅ Firestore Write: WORKING")
                
                // Clean up test document
                try await testRef.delete()
                print("   ✅ Firestore Delete: WORKING")
                
                // Test conversation creation permissions
                print("\n📝 Testing Conversation Permissions...")
                let testConvRef = db.collection("conversations").document("test_\(UUID().uuidString)")
                try await testConvRef.setData([
                    "id": testConvRef.documentID,
                    "isGroup": false,
                    "participantIDs": [Auth.auth().currentUser?.uid ?? ""],
                    "lastMessage": "Test",
                    "lastMessageTime": Timestamp(date: Date()),
                    "unreadBy": []
                ])
                print("   ✅ Can create conversations")
                
                // Test message creation permissions
                print("   Testing message creation...")
                let testMsgRef = testConvRef.collection("messages").document("test_msg")
                try await testMsgRef.setData([
                    "id": testMsgRef.documentID,
                    "conversationID": testConvRef.documentID,
                    "senderID": Auth.auth().currentUser?.uid ?? "",
                    "content": "Test message",
                    "timestamp": Timestamp(date: Date()),
                    "status": "sent",
                    "type": "text",
                    "readBy": []
                ])
                print("   ✅ Can create messages")
                
                // Clean up test conversation and message
                try await testMsgRef.delete()
                try await testConvRef.delete()
                print("   ✅ Test cleanup successful")
                
                // Check Firestore settings
                print("\n⚙️  Firestore Settings:")
                let settings = db.settings
                print("   Host: \(settings.host)")
                print("   SSL Enabled: \(settings.isSSLEnabled)")
                print("   Cache Enabled: \(settings.cacheSettings != nil)")
                
            } catch let error as NSError {
                print("\n❌ Firestore Error Detected:")
                print("   Error Domain: \(error.domain)")
                print("   Error Code: \(error.code)")
                print("   Description: \(error.localizedDescription)")
                
                // Provide specific guidance based on error
                if error.domain == "FIRFirestoreErrorDomain" {
                    switch error.code {
                    case 7: // PERMISSION_DENIED
                        print("\n   🔒 PERMISSION DENIED")
                        print("   This means Firestore security rules are blocking the operation.")
                        print("   Check your firestore.rules file and ensure:")
                        print("   1. Rules allow authenticated users to read/write")
                        print("   2. Rules have been deployed with: firebase deploy --only firestore:rules")
                        
                    case 14: // UNAVAILABLE
                        print("\n   🌐 SERVICE UNAVAILABLE")
                        print("   This could mean:")
                        print("   1. No internet connection")
                        print("   2. Firestore service is down")
                        print("   3. Network firewall blocking Firebase")
                        
                    case 16: // UNAUTHENTICATED
                        print("\n   🔐 UNAUTHENTICATED")
                        print("   User is not properly authenticated.")
                        print("   Try signing out and back in.")
                        
                    default:
                        print("\n   Unknown Firestore error code: \(error.code)")
                    }
                }
                
                print("\n   Full error info: \(error.userInfo)")
            } catch {
                print("\n❌ Unexpected Error: \(error.localizedDescription)")
            }
            
            print("\n" + String(repeating: "=", count: 60))
            print("📋 DIAGNOSTICS COMPLETE")
            print(String(repeating: "=", count: 60) + "\n")
        }
    }
    
    // Quick test for a specific operation
    static func testSendMessage(conversationID: String, content: String) {
        print("\n🧪 Testing Message Send...")
        print("   Conversation ID: \(conversationID)")
        print("   Content: \(content)")
        
        guard let currentUser = Auth.auth().currentUser else {
            print("   ❌ Not authenticated")
            return
        }
        
        let db = Firestore.firestore()
        
        Task {
            do {
                let messageRef = db.collection("conversations")
                    .document(conversationID)
                    .collection("messages")
                    .document()
                
                try await messageRef.setData([
                    "id": messageRef.documentID,
                    "conversationID": conversationID,
                    "senderID": currentUser.uid,
                    "content": content,
                    "timestamp": Timestamp(date: Date()),
                    "status": "sent",
                    "type": "text",
                    "readBy": []
                ])
                
                print("   ✅ Message sent successfully!")
                print("   Message ID: \(messageRef.documentID)")
                
            } catch {
                print("   ❌ Failed to send message: \(error.localizedDescription)")
            }
        }
    }
}

