import Time "mo:base/Time";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";

actor ImpactOracle {
    
    // Data Types
    public type Location = {
        latitude: Float;
        longitude: Float;
        country: Text;
    };
    
    public type Evidence = {
        imageUrl: Text;
        description: Text;
        timestamp: Int;
    };
    
    public type ImpactAction = {
        id: Nat;
        submitter: Principal;
        actionType: Text; // "tree_plant", "beach_cleanup", "education", "elderly_care"
        location: Location;
        evidence: Evidence;
        verificationScore: Float;
        isVerified: Bool;
        impactTokens: Nat;
        carbonOffset: ?Float;
        createdAt: Int;
        verifiedAt: ?Int;
    };
    
    public type ImpactToken = {
        id: Nat;
        actionId: Nat;
        owner: Principal;
        tokenType: Text;
        value: Nat;
        carbonEquivalent: ?Float;
        createdAt: Int;
    };
    
    // Hash functions
    private func natHash(n: Nat) : Hash.Hash {
        Text.hash(Nat.toText(n))
    };
    
    private func principalHash(p: Principal) : Hash.Hash {
        Text.hash(Principal.toText(p))
    };
    
    // State Variables
    private stable var nextActionId: Nat = 1;
    private stable var nextTokenId: Nat = 1;
    private var actions = HashMap.HashMap<Nat, ImpactAction>(10, Nat.equal, natHash);
    private var tokens = HashMap.HashMap<Nat, ImpactToken>(10, Nat.equal, natHash);
    private var userActions = HashMap.HashMap<Principal, [Nat]>(10, Principal.equal, principalHash);
    
    // Reward Constants
    private let MIN_VERIFICATION_SCORE: Float = 0.75;
    private let TREE_PLANT_REWARD: Nat = 100;
    private let CLEANUP_REWARD: Nat = 50;
    private let EDUCATION_REWARD: Nat = 200;
    private let CARE_REWARD: Nat = 150;
    
    // Submit Impact Action
    public shared(msg) func submitImpactAction(
        actionType: Text,
        location: Location,
        evidence: Evidence
    ) : async Result.Result<Nat, Text> {
        
        let actionId = nextActionId;
        nextActionId += 1;
        
        let action: ImpactAction = {
            id = actionId;
            submitter = msg.caller;
            actionType = actionType;
            location = location;
            evidence = evidence;
            verificationScore = 0.0;
            isVerified = false;
            impactTokens = 0;
            carbonOffset = null;
            createdAt = Time.now();
            verifiedAt = null;
        };
        
        actions.put(actionId, action);
        
        // Add to user's action list
        switch (userActions.get(msg.caller)) {
            case (?existing) {
                userActions.put(msg.caller, Array.append(existing, [actionId]));
            };
            case null {
                userActions.put(msg.caller, [actionId]);
            };
        };
        
        // Auto-verify for demo (in production, this would be AI verification)
        ignore verifyAction(actionId);
        
        #ok(actionId)
    };
    
    // Verification Process (Simplified for hackathon)
    private func verifyAction(actionId: Nat) : async () {
        switch (actions.get(actionId)) {
            case (?action) {
                // Simulate AI verification with high score for demo
                let verificationScore = 0.9;
                let rewards = calculateRewards(action.actionType);
                let carbonOffset = calculateCarbonOffset(action.actionType);
                
                let verifiedAction: ImpactAction = {
                    action with
                    verificationScore = verificationScore;
                    isVerified = true;
                    impactTokens = rewards;
                    carbonOffset = carbonOffset;
                    verifiedAt = ?Time.now();
                };
                
                actions.put(actionId, verifiedAction);
                
                // Mint impact tokens
                ignore mintImpactTokens(actionId, action.submitter, rewards, action.actionType);
            };
            case null { };
        };
    };
    
    // Calculate Rewards
    private func calculateRewards(actionType: Text) : Nat {
        switch (actionType) {
            case ("tree_plant") { TREE_PLANT_REWARD };
            case ("beach_cleanup") { CLEANUP_REWARD };
            case ("education") { EDUCATION_REWARD };
            case ("elderly_care") { CARE_REWARD };
            case (_) { 25 };
        };
    };
    
    // Calculate Carbon Offset
    private func calculateCarbonOffset(actionType: Text) : ?Float {
        switch (actionType) {
            case ("tree_plant") { ?22.0 }; // kg CO2 per tree
            case ("beach_cleanup") { ?5.0 }; // indirect environmental benefit
            case (_) { null };
        };
    };
    
    // Mint Impact Tokens
    private func mintImpactTokens(
        actionId: Nat,
        recipient: Principal,
        amount: Nat,
        tokenType: Text
    ) : async Nat {
        let tokenId = nextTokenId;
        nextTokenId += 1;
        
        let token: ImpactToken = {
            id = tokenId;
            actionId = actionId;
            owner = recipient;
            tokenType = tokenType;
            value = amount;
            carbonEquivalent = calculateCarbonOffset(tokenType);
            createdAt = Time.now();
        };
        
        tokens.put(tokenId, token);
        tokenId
    };
    
    // Query Functions
    public query func getAction(actionId: Nat) : async ?ImpactAction {
        actions.get(actionId)
    };
    
    public query func getUserActions(user: Principal) : async [Nat] {
        switch (userActions.get(user)) {
            case (?actionIds) { actionIds };
            case null { [] };
        };
    };
    
    public query func getVerifiedActions() : async [ImpactAction] {
        var verified: [ImpactAction] = [];
        for ((id, action) in actions.entries()) {
            if (action.isVerified) {
                verified := Array.append(verified, [action]);
            };
        };
        verified
    };
    
    public query func getUserTokens(user: Principal) : async [ImpactToken] {
        var userTokens: [ImpactToken] = [];
        for ((id, token) in tokens.entries()) {
            if (token.owner == user) {
                userTokens := Array.append(userTokens, [token]);
            };
        };
        userTokens
    };
    
    public query func getStats() : async {totalActions: Nat; totalTokens: Nat; totalValue: Nat} {
        var totalActions = 0;
        var totalTokens = 0;
        var totalValue = 0;
        
        for ((id, action) in actions.entries()) {
            totalActions += 1;
            if (action.isVerified) {
                totalTokens += action.impactTokens;
                totalValue += action.impactTokens * 50; // $0.50 per token
            };
        };
        
        {totalActions = totalActions; totalTokens = totalTokens; totalValue = totalValue}
    };
    
    // Simple greeting (keeping from original template)
    public query func greet(name: Text) : async Text {
        return "Welcome to ImpactOracle, " # name # "! Turn your good deeds into digital gold! 🌍💰";
    };
}