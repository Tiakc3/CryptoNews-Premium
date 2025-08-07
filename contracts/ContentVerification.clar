;; Content Verification and Credibility System
;; Enables fact-checking, source verification, and credibility tracking for crypto news

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-ALREADY-VERIFIED (err u201))
(define-constant ERR-INVALID-CHALLENGE (err u202))
(define-constant ERR-CHALLENGE-EXPIRED (err u203))
(define-constant ERR-ALREADY-VOTED (err u204))
(define-constant ERR-INSUFFICIENT-STAKE (err u205))
(define-constant ERR-SOURCE-EXISTS (err u206))
(define-constant ERR-INVALID-SCORE (err u207))

;; System constants
(define-constant FACT-CHECKER-STAKE u500)
(define-constant CHALLENGE-PERIOD u2880) ;; ~20 days in blocks
(define-constant MIN-VERIFICATION-VOTES u3)
(define-constant CREDIBILITY-DECAY-RATE u5) ;; 5% per period
(define-constant MAX-CREDIBILITY-SCORE u1000)

;; Data variables
(define-data-var verification-counter uint u0)
(define-data-var challenge-counter uint u0)

;; Source registration and credibility tracking
(define-map verified-sources
    principal
    {name: (string-ascii 100),
     domain: (string-ascii 200),
     credibility-score: uint,
     verification-count: uint,
     last-updated: uint,
     total-challenges: uint,
     successful-challenges: uint})

;; Fact-checker registration with stake requirements
(define-map fact-checkers
    principal
    {stake-amount: uint,
     reputation: uint,
     verifications-done: uint,
     challenges-won: uint,
     active-since: uint})

;; Content verification records
(define-map content-verifications
    uint ;; content-id from main contract
    {source: principal,
     fact-checker: principal,
     verification-score: uint, ;; 0-100 accuracy score
     verification-timestamp: uint,
     challenge-period-end: uint,
     is-challenged: bool,
     final-credibility: uint})

;; Fact-checking challenges
(define-map verification-challenges
    uint ;; challenge-id
    {content-id: uint,
     challenger: principal,
     reason: (string-ascii 200),
     created-at: uint,
     votes-accurate: uint,
     votes-inaccurate: uint,
     resolved: bool,
     resolution-timestamp: uint})

;; Challenge voting records
(define-map challenge-votes
    {challenge-id: uint, voter: principal}
    {vote: bool, ;; true = accurate, false = inaccurate
     timestamp: uint,
     stake-weight: uint})

;; Source citation tracking
(define-map content-citations
    uint ;; content-id
    {primary-sources: (list 5 (string-ascii 200)),
     secondary-sources: (list 5 (string-ascii 200)),
     citation-count: uint,
     reliability-rating: uint})

;; Public functions

;; Register as a fact-checker with required stake
(define-public (register-fact-checker)
    (let ((caller tx-sender))
        (asserts! (is-none (map-get? fact-checkers caller)) ERR-SOURCE-EXISTS)
        (try! (stx-transfer? FACT-CHECKER-STAKE caller (as-contract tx-sender)))
        (ok (map-set fact-checkers
            caller
            {stake-amount: FACT-CHECKER-STAKE,
             reputation: u100,
             verifications-done: u0,
             challenges-won: u0,
             active-since: stacks-block-height}))))

;; Register a verified news source
(define-public (register-source (name (string-ascii 100)) (domain (string-ascii 200)))
    (let ((caller tx-sender))
        (asserts! (is-none (map-get? verified-sources caller)) ERR-SOURCE-EXISTS)
        (ok (map-set verified-sources
            caller
            {name: name,
             domain: domain,
             credibility-score: u500, ;; Start with medium credibility
             verification-count: u0,
             last-updated: stacks-block-height,
             total-challenges: u0,
             successful-challenges: u0}))))

;; Verify content accuracy and assign credibility score
(define-public (verify-content (content-id uint) (source principal) (accuracy-score uint))
    (let ((caller tx-sender)
          (checker-info (unwrap! (map-get? fact-checkers caller) ERR-NOT-AUTHORIZED))
          (source-info (unwrap! (map-get? verified-sources source) ERR-NOT-AUTHORIZED)))
        (asserts! (and (>= accuracy-score u0) (<= accuracy-score u100)) ERR-INVALID-SCORE)
        (asserts! (is-none (map-get? content-verifications content-id)) ERR-ALREADY-VERIFIED)
        
        (let ((verification-id (+ (var-get verification-counter) u1))
              (credibility-bonus (if (>= accuracy-score u80) u10 u0))
              (new-credibility (min (+ (get credibility-score source-info) credibility-bonus) MAX-CREDIBILITY-SCORE)))
            
            (var-set verification-counter verification-id)
            
            ;; Record the verification
            (map-set content-verifications
                content-id
                {source: source,
                 fact-checker: caller,
                 verification-score: accuracy-score,
                 verification-timestamp: stacks-block-height,
                 challenge-period-end: (+ stacks-block-height CHALLENGE-PERIOD),
                 is-challenged: false,
                 final-credibility: accuracy-score})
            
            ;; Update source credibility
            (map-set verified-sources
                source
                (merge source-info 
                    {credibility-score: new-credibility,
                     verification-count: (+ (get verification-count source-info) u1),
                     last-updated: stacks-block-height}))
            
            ;; Update fact-checker stats
            (map-set fact-checkers
                caller
                (merge checker-info 
                    {verifications-done: (+ (get verifications-done checker-info) u1)}))
            
            (ok verification-id))))

;; Challenge a content verification
(define-public (challenge-verification (content-id uint) (reason (string-ascii 200)))
    (let ((caller tx-sender)
          (checker-info (unwrap! (map-get? fact-checkers caller) ERR-NOT-AUTHORIZED))
          (verification (unwrap! (map-get? content-verifications content-id) ERR-INVALID-CHALLENGE)))
        
        (asserts! (< stacks-block-height (get challenge-period-end verification)) ERR-CHALLENGE-EXPIRED)
        (asserts! (not (get is-challenged verification)) ERR-ALREADY-VERIFIED)
        
        (let ((challenge-id (+ (var-get challenge-counter) u1)))
            (var-set challenge-counter challenge-id)
            
            ;; Create challenge
            (map-set verification-challenges
                challenge-id
                {content-id: content-id,
                 challenger: caller,
                 reason: reason,
                 created-at: stacks-block-height,
                 votes-accurate: u0,
                 votes-inaccurate: u0,
                 resolved: false,
                 resolution-timestamp: u0})
            
            ;; Mark verification as challenged
            (map-set content-verifications
                content-id
                (merge verification {is-challenged: true}))
            
            (ok challenge-id))))

;; Vote on a verification challenge
(define-public (vote-on-challenge (challenge-id uint) (vote-accurate bool))
    (let ((caller tx-sender)
          (checker-info (unwrap! (map-get? fact-checkers caller) ERR-NOT-AUTHORIZED))
          (challenge (unwrap! (map-get? verification-challenges challenge-id) ERR-INVALID-CHALLENGE))
          (vote-key {challenge-id: challenge-id, voter: caller}))
        
        (asserts! (not (get resolved challenge)) ERR-CHALLENGE-EXPIRED)
        (asserts! (is-none (map-get? challenge-votes vote-key)) ERR-ALREADY-VOTED)
        
        (let ((stake-weight (get stake-amount checker-info)))
            ;; Record vote
            (map-set challenge-votes vote-key
                {vote: vote-accurate,
                 timestamp: stacks-block-height,
                 stake-weight: stake-weight})
            
            ;; Update challenge vote counts
            (if vote-accurate
                (map-set verification-challenges challenge-id
                    (merge challenge {votes-accurate: (+ (get votes-accurate challenge) u1)}))
                (map-set verification-challenges challenge-id
                    (merge challenge {votes-inaccurate: (+ (get votes-inaccurate challenge) u1)})))
            
            (ok true))))

;; Resolve a verification challenge after voting period
(define-public (resolve-challenge (challenge-id uint))
    (let ((challenge (unwrap! (map-get? verification-challenges challenge-id) ERR-INVALID-CHALLENGE))
          (content-id (get content-id challenge))
          (verification (unwrap! (map-get? content-verifications content-id) ERR-INVALID-CHALLENGE))
          (source (get source verification))
          (source-info (unwrap! (map-get? verified-sources source) ERR-NOT-AUTHORIZED)))
        
        (asserts! (not (get resolved challenge)) ERR-CHALLENGE-EXPIRED)
        (let ((total-votes (+ (get votes-accurate challenge) (get votes-inaccurate challenge)))
              (votes-accurate (get votes-accurate challenge))
              (votes-inaccurate (get votes-inaccurate challenge)))
            
            (asserts! (>= total-votes MIN-VERIFICATION-VOTES) ERR-INSUFFICIENT-STAKE)
            
            ;; Mark challenge as resolved
            (map-set verification-challenges challenge-id
                (merge challenge 
                    {resolved: true,
                     resolution-timestamp: stacks-block-height}))
            
            ;; Update source credibility based on challenge outcome
            (let ((credibility-change (if (> votes-accurate votes-inaccurate)
                                        u0 ;; Challenge failed - no penalty
                                        u50)) ;; Challenge succeeded - penalty
                  (new-credibility (if (> votes-accurate votes-inaccurate)
                                     (get credibility-score source-info)
                                     (if (>= (get credibility-score source-info) u50)
                                         (- (get credibility-score source-info) u50)
                                         u0))))
                
                ;; Update source info
                (map-set verified-sources source
                    (merge source-info 
                        {credibility-score: new-credibility,
                         total-challenges: (+ (get total-challenges source-info) u1),
                         successful-challenges: (+ (get successful-challenges source-info) 
                                                  (if (> votes-inaccurate votes-accurate) u1 u0))}))
                
                ;; Update challenger reputation if challenge was successful
                (if (> votes-inaccurate votes-accurate)
                    (let ((challenger-info (unwrap! (map-get? fact-checkers (get challenger challenge)) ERR-NOT-AUTHORIZED)))
                        (map-set fact-checkers (get challenger challenge)
                            (merge challenger-info 
                                {challenges-won: (+ (get challenges-won challenger-info) u1),
                                 reputation: (min (+ (get reputation challenger-info) u20) u1000)})))
                    true)
                
                (ok (> votes-inaccurate votes-accurate))))))

;; Add citations to content
(define-public (add-content-citations 
    (content-id uint)
    (primary-sources (list 5 (string-ascii 200)))
    (secondary-sources (list 5 (string-ascii 200))))
    (let ((caller tx-sender))
        (asserts! (is-some (map-get? fact-checkers caller)) ERR-NOT-AUTHORIZED)
        (let ((citation-count (+ (len primary-sources) (len secondary-sources))))
            (ok (map-set content-citations
                content-id
                {primary-sources: primary-sources,
                 secondary-sources: secondary-sources,
                 citation-count: citation-count,
                 reliability-rating: (min (* citation-count u20) u100)})))))

;; Read-only functions

(define-read-only (get-source-credibility (source principal))
    (map-get? verified-sources source))

(define-read-only (get-fact-checker-info (checker principal))
    (map-get? fact-checkers checker))

(define-read-only (get-content-verification (content-id uint))
    (map-get? content-verifications content-id))

(define-read-only (get-challenge-info (challenge-id uint))
    (map-get? verification-challenges challenge-id))

(define-read-only (get-content-citations (content-id uint))
    (map-get? content-citations content-id))

(define-read-only (is-content-verified (content-id uint))
    (is-some (map-get? content-verifications content-id)))

(define-read-only (get-credibility-badge (source principal))
    (match (map-get? verified-sources source)
        source-info 
            (let ((score (get credibility-score source-info)))
                (if (>= score u800) "gold"
                    (if (>= score u600) "silver"
                        (if (>= score u400) "bronze"
                            "unverified"))))
        "unverified"))

;; Private helper functions
(define-private (min (a uint) (b uint))
    (if (<= a b) a b))
