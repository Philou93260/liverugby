//
//  FirebaseService.swift
//  LiverugbyApp
//
//  Service de gestion Firebase
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private init() {
        checkAuthState()
    }
    
    // MARK: - Authentication
    
    func checkAuthState() {
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                if let user = user {
                    await self?.fetchUserProfile(uid: user.uid)
                }
            }
        }
    }
    
    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        
        await fetchUserProfile(uid: result.user.uid)
    }
    
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        await fetchUserProfile(uid: result.user.uid)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
        isAuthenticated = false
    }
    
    // MARK: - Firestore Operations
    
    func fetchUserProfile(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            if let user = try? document.data(as: User.self) {
                currentUser = user
            }
        } catch {
            print("Erreur récupération profil: \(error.localizedDescription)")
        }
    }
    
    func updateUserProfile(user: User) async throws {
        guard let uid = user.id else { return }
        try db.collection("users").document(uid).setData(from: user, merge: true)
        currentUser = user
    }
    
    func fetchCollection<T: Codable>(
        collection: String,
        limit: Int = 50
    ) async throws -> [T] {
        let snapshot = try await db.collection(collection)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: T.self)
        }
    }
    
    func addDocument<T: Codable>(
        to collection: String,
        data: T
    ) async throws -> String {
        let ref = try db.collection(collection).addDocument(from: data)
        return ref.documentID
    }
    
    func updateDocument<T: Codable>(
        collection: String,
        documentId: String,
        data: T
    ) async throws {
        try db.collection(collection).document(documentId).setData(from: data, merge: true)
    }
    
    func deleteDocument(collection: String, documentId: String) async throws {
        try await db.collection(collection).document(documentId).delete()
    }
    
    // MARK: - Storage Operations
    
    func uploadImage(_ image: UIImage, path: String) async throws -> URL {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Impossible de convertir l'image"
            ])
        }
        
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        
        return downloadURL
    }
    
    func deleteFile(path: String) async throws {
        let ref = storage.reference().child(path)
        try await ref.delete()
    }
}

// MARK: - Extensions

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage ?? self
    }
}
