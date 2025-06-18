;; CryptoNews Premium
;; Tiered access to verified crypto news and analysis

;; Constants for subscription tiers
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-SUBSCRIBED (err u101))
(define-constant ERR-NO-SUBSCRIPTION (err u102))
(define-constant contract-owner tx-sender)

;; Subscription tiers pricing in STX
(define-constant BASIC-TIER-PRICE u100)
(define-constant PRO-TIER-PRICE u500)
(define-constant ELITE-TIER-PRICE u1000)

(define-constant ERR-NOT-MODERATOR (err u105))
(define-constant ERR-ALREADY-FLAGGED (err u106))
(define-constant ERR-VOTING-ENDED (err u107))
(define-constant ERR-ALREADY-VOTED (err u108))

(define-constant MODERATOR-STAKE u1000)
(define-constant VOTING-PERIOD u1440)
(define-constant MIN-VOTES-REQUIRED u3)

(define-map moderators
    principal
    {stake: uint, reputation: uint, active: bool})

(define-map content-flags
    uint
    {reporter: principal,
     reason: (string-ascii 100),
     flagged-at: uint,
     votes-for: uint,
     votes-against: uint,
     resolved: bool,
     voting-ends: uint})

(define-map moderation-votes
    {content-id: uint, voter: principal}
    {vote: bool, voted-at: uint})

(define-map content-status
    uint
    {hidden: bool, strike-count: uint})

;; Data maps
(define-map subscriptions
    principal
    {tier: (string-ascii 20), expiration: uint}
)

(define-map news-content
    uint
    {title: (string-ascii 100), 
     content: (string-ascii 500),
     tier: (string-ascii 20)}
)

;; Public functions
(define-public (subscribe-to-tier (tier-name (string-ascii 20)))
    (let ((caller tx-sender)
          (price (get-tier-price tier-name)))
        (asserts! (is-none (get-subscription-details caller)) ERR-ALREADY-SUBSCRIBED)
        (try! (stx-transfer? price caller (as-contract tx-sender)))
        (ok (map-set subscriptions 
            caller 
            {tier: tier-name, 
             expiration: (+ stacks-block-height u8640)}))))

(define-public (add-news (id uint) 
                        (title (string-ascii 100))
                        (content (string-ascii 500))
                        (tier (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set news-content 
            id
            {title: title,
             content: content,
             tier: tier}))))

;; Read only functions
(define-read-only (get-subscription-details (user principal))
    (map-get? subscriptions user))

(define-read-only (get-news (id uint))
    (let ((news (unwrap! (map-get? news-content id) ERR-NO-SUBSCRIPTION))
          (user-sub (unwrap! (get-subscription-details tx-sender) ERR-NO-SUBSCRIPTION)))
        (asserts! (can-access-tier (get tier news) (get tier user-sub)) ERR-NOT-AUTHORIZED)
        (ok news)))

;; Private functions
(define-private (get-tier-price (tier-name (string-ascii 20)))
    (if (is-eq tier-name "basic")
        BASIC-TIER-PRICE
        (if (is-eq tier-name "pro")
            PRO-TIER-PRICE
            (if (is-eq tier-name "elite")
                ELITE-TIER-PRICE
                BASIC-TIER-PRICE))))

(define-private (can-access-tier (content-tier (string-ascii 20)) (user-tier (string-ascii 20)))
    (if (is-eq user-tier "elite")
        true
        (if (is-eq user-tier "pro")
            (or (is-eq content-tier "pro") (is-eq content-tier "basic"))
            (if (is-eq user-tier "basic")
                (is-eq content-tier "basic")
                false))))


(define-public (renew-subscription)
    (let ((caller tx-sender)
          (current-sub (unwrap! (get-subscription-details caller) ERR-NO-SUBSCRIPTION))
          (tier-price (get-tier-price (get tier current-sub))))
        (try! (stx-transfer? tier-price caller (as-contract tx-sender)))
        (ok (map-set subscriptions 
            caller 
            {tier: (get tier current-sub), 
             expiration: (+ stacks-block-height u8640)}))))


(define-public (upgrade-subscription (new-tier (string-ascii 20)))
    (let ((caller tx-sender)
          (current-sub (unwrap! (get-subscription-details caller) ERR-NO-SUBSCRIPTION))
          (price-difference (- (get-tier-price new-tier) (get-tier-price (get tier current-sub)))))
        (asserts! (> price-difference u0) ERR-NOT-AUTHORIZED)
        (try! (stx-transfer? price-difference caller (as-contract tx-sender)))
        (ok (map-set subscriptions 
            caller 
            {tier: new-tier, 
             expiration: (get expiration current-sub)}))))


(define-map news-comments 
    {news-id: uint, comment-id: uint}
    {author: principal, content: (string-ascii 280), timestamp: uint})

(define-data-var comment-counter uint u0)

(define-public (add-comment (news-id uint) (content (string-ascii 280)))
    (let ((comment-id (+ (var-get comment-counter) u1))
          (caller tx-sender))
        (asserts! (is-some (get-subscription-details caller)) ERR-NOT-AUTHORIZED)
        (var-set comment-counter comment-id)
        (ok (map-set news-comments
            {news-id: news-id, comment-id: comment-id}
            {author: caller, content: content, timestamp: stacks-block-height}))))


(define-map bookmarks
    {user: principal, news-id: uint}
    {timestamp: uint})

(define-public (toggle-bookmark (news-id uint))
    (let ((caller tx-sender))
        (asserts! (is-some (get-subscription-details caller)) ERR-NOT-AUTHORIZED)
        (if (is-some (map-get? bookmarks {user: caller, news-id: news-id}))
            (ok (map-delete bookmarks {user: caller, news-id: news-id}))
            (ok (map-set bookmarks 
                {user: caller, news-id: news-id}
                {timestamp: stacks-block-height})))))


(define-map news-ratings
    {news-id: uint, user: principal}
    {rating: uint})

(define-public (rate-news (news-id uint) (rating uint))
    (let ((caller tx-sender))
        (asserts! (and (>= rating u1) (<= rating u5)) (err u103))
        (asserts! (is-some (get-subscription-details caller)) ERR-NOT-AUTHORIZED)
        (ok (map-set news-ratings
            {news-id: news-id, user: caller}
            {rating: rating}))))



(define-constant VALID-CATEGORIES (list "defi" "nft" "trading" "regulation" "technology"))

(define-map news-categories
    uint
    (list 10 (string-ascii 20)))

(define-public (set-news-categories (news-id uint) (categories (list 10 (string-ascii 20))))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set news-categories news-id categories))))



(define-map authors
    principal
    {name: (string-ascii 50), bio: (string-ascii 200)})

(define-public (register-author (name (string-ascii 50)) (bio (string-ascii 200)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set authors
            tx-sender
            {name: name, bio: bio}))))




(define-map news-tags
    uint
    (list 10 (string-ascii 20)))

(define-public (add-news-tags (news-id uint) (tags (list 10 (string-ascii 20))))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set news-tags news-id tags))))

(define-private (check-news-tag (news-tag {id: uint, value: (list 10 (string-ascii 20))}) (search-tag (string-ascii 20)))
    (is-some (index-of? (get value news-tag) search-tag)))



(define-constant ERR-PROFILE-EXISTS (err u104))

;; with other data maps
(define-map user-profiles
    principal
    {username: (string-ascii 50),
     bio: (string-ascii 200),
     avatar-url: (string-ascii 200),
     joined-date: uint})

(define-public (create-profile 
    (username (string-ascii 50))
    (bio (string-ascii 200))
    (avatar-url (string-ascii 200)))
    (let ((caller tx-sender))
        (asserts! (is-none (map-get? user-profiles caller)) ERR-PROFILE-EXISTS)
        (ok (map-set user-profiles
            caller
            {username: username,
             bio: bio,
             avatar-url: avatar-url,
             joined-date: stacks-block-height}))))

(define-read-only (get-profile (user principal))
    (map-get? user-profiles user))


;; with other constants
(define-constant COMMENT-POINTS u5)
(define-constant RATING-POINTS u2)
(define-constant SHARE-POINTS u3)

;; with other data maps
(define-map user-points
    principal
    {points: uint,
     last-updated: uint})

(define-public (award-points (points uint))
    (let ((caller tx-sender)
          (current-points (default-to u0 (get points (map-get? user-points caller)))))
        (ok (map-set user-points
            caller
            {points: (+ current-points points),
             last-updated: stacks-block-height}))))

(define-read-only (get-user-points (user principal))
    (map-get? user-points user))


        (define-map search-index
        (string-ascii 20)
        (list 100 uint))
    
    (define-public (index-content (news-id uint) (keywords (list 10 (string-ascii 20))))
        (begin
            (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
            (map add-to-index keywords)
            (ok true)))
    
    (define-private (add-to-index (keyword (string-ascii 20)))
        (let ((existing-ids (default-to (list) (map-get? search-index keyword))))
            (map-set search-index keyword existing-ids)))
    
    (define-read-only (search-by-keyword (keyword (string-ascii 20)))
        (map-get? search-index keyword))



(define-map content-previews
    uint
    {preview-text: (string-ascii 100),
     preview-expires: uint})

(define-public (add-content-preview 
    (news-id uint)
    (preview-text (string-ascii 100)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set content-previews
            news-id
            {preview-text: preview-text,
             preview-expires: (+ stacks-block-height u1440)}))))

(define-read-only (get-content-preview (news-id uint))
    (map-get? content-previews news-id))



;; with other data maps
(define-map newsletter-subscriptions
    principal
    {email-hash: (buff 32),
     preferences: (list 5 (string-ascii 20)),
     subscribed-at: uint})

(define-public (subscribe-to-newsletter 
    (email-hash (buff 32))
    (preferences (list 5 (string-ascii 20))))
    (let ((caller tx-sender))
        (asserts! (is-some (get-subscription-details caller)) ERR-NOT-AUTHORIZED)
        (ok (map-set newsletter-subscriptions
            caller
            {email-hash: email-hash,
             preferences: preferences,
             subscribed-at: stacks-block-height}))))

(define-public (update-newsletter-preferences 
    (new-preferences (list 5 (string-ascii 20))))
    (let ((caller tx-sender)
          (current-sub (unwrap! (map-get? newsletter-subscriptions caller) ERR-NOT-AUTHORIZED)))
        (ok (map-set newsletter-subscriptions
            caller
            {email-hash: (get email-hash current-sub),
             preferences: new-preferences,
             subscribed-at: (get subscribed-at current-sub)}))))


;; with other constants
(define-constant REFERRAL-REWARD u50)

;; with other data maps
(define-map referrals
    principal
    {referrer: principal,
     referred-at: uint,
     reward-claimed: bool})

(define-public (refer-user (new-user principal))
    (let ((referrer tx-sender))
        (asserts! (is-some (get-subscription-details referrer)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? referrals new-user)) ERR-ALREADY-SUBSCRIBED)
        (ok (map-set referrals
            new-user
            {referrer: referrer,
             referred-at: stacks-block-height,
             reward-claimed: false}))))

(define-public (claim-referral-reward)
    (let ((caller tx-sender)
          (referral (unwrap! (map-get? referrals caller) ERR-NOT-AUTHORIZED)))
        (asserts! (not (get reward-claimed referral)) ERR-NOT-AUTHORIZED)
        (try! (stx-transfer? REFERRAL-REWARD (as-contract tx-sender) (get referrer referral)))
        (ok (map-set referrals
            caller
            {referrer: (get referrer referral),
             referred-at: (get referred-at referral),
             reward-claimed: true}))))


(define-constant SHARE-REWARD u10)
(define-constant MAX-SHARES-PER-DAY u5)

(define-map content-shares 
    {user: principal, news-id: uint}
    {share-count: uint, last-shared: uint})

(define-map daily-share-counts
    {user: principal, day: uint}
    uint)

(define-private (get-current-day)
    (/ stacks-block-height u144))

(define-public (share-content (news-id uint) (recipient principal))
    (let (
        (caller tx-sender)
        (current-day (get-current-day))
        (daily-shares (get-daily-shares caller current-day))
    )
        (asserts! (is-some (get-subscription-details caller)) ERR-NOT-AUTHORIZED)
        (asserts! (< daily-shares MAX-SHARES-PER-DAY) ERR-NOT-AUTHORIZED)
        (try! (stx-transfer? SHARE-REWARD (as-contract tx-sender) caller))
        (map-set daily-share-counts 
            {user: caller, day: current-day}
            (+ daily-shares u1))
        (ok true)))
(define-read-only (get-daily-shares (user principal) (day uint))
    (get-shares-count (map-get? daily-share-counts {user: user, day: day})))

(define-private (get-shares-count (shares (optional uint)))
    (default-to u0 shares))



(define-constant MARKETPLACE-FEE u50)

(define-map premium-content
    uint 
    {creator: principal,
     price: uint,
     access-count: uint,
     max-access: uint})

(define-map content-access
    {user: principal, content-id: uint}
    bool)

(define-public (list-premium-content (content-id uint) (price uint) (max-access uint))
    (let ((caller tx-sender))
        (asserts! (is-eq caller contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set premium-content
            content-id
            {creator: caller,
             price: price,
             access-count: u0,
             max-access: max-access}))))

(define-public (purchase-content-access (content-id uint))
    (let (
        (caller tx-sender)
        (content (unwrap! (map-get? premium-content content-id) ERR-NO-SUBSCRIPTION))
    )
        (asserts! (< (get access-count content) (get max-access content)) ERR-NOT-AUTHORIZED)
        (try! (stx-transfer? (get price content) caller (get creator content)))
        (map-set premium-content
            content-id
            (merge content {access-count: (+ (get access-count content) u1)}))
        (map-set content-access
            {user: caller, content-id: content-id}
            true)
        (ok true)))



(define-public (register-as-moderator)
    (let ((caller tx-sender))
        (asserts! (is-none (map-get? moderators caller)) ERR-ALREADY-SUBSCRIBED)
        (try! (stx-transfer? MODERATOR-STAKE caller (as-contract tx-sender)))
        (ok (map-set moderators
            caller
            {stake: MODERATOR-STAKE,
             reputation: u100,
             active: true}))))

(define-public (flag-content (content-id uint) (reason (string-ascii 100)))
    (let ((caller tx-sender))
        (asserts! (is-some (get-moderator-info caller)) ERR-NOT-MODERATOR)
        (asserts! (is-none (map-get? content-flags content-id)) ERR-ALREADY-FLAGGED)
        (ok (map-set content-flags
            content-id
            {reporter: caller,
             reason: reason,
             flagged-at: stacks-block-height,
             votes-for: u0,
             votes-against: u0,
             resolved: false,
             voting-ends: (+ stacks-block-height VOTING-PERIOD)}))))

(define-public (vote-on-flag (content-id uint) (support-flag bool))
    (let (
        (caller tx-sender)
        (flag-info (unwrap! (map-get? content-flags content-id) ERR-NO-SUBSCRIPTION))
        (vote-key {content-id: content-id, voter: caller})
    )
        (asserts! (is-some (get-moderator-info caller)) ERR-NOT-MODERATOR)
        (asserts! (not (get resolved flag-info)) ERR-VOTING-ENDED)
        (asserts! (< stacks-block-height (get voting-ends flag-info)) ERR-VOTING-ENDED)
        (asserts! (is-none (map-get? moderation-votes vote-key)) ERR-ALREADY-VOTED)
        
        (map-set moderation-votes vote-key {vote: support-flag, voted-at: stacks-block-height})
        
        (if support-flag
            (map-set content-flags content-id
                (merge flag-info {votes-for: (+ (get votes-for flag-info) u1)}))
            (map-set content-flags content-id
                (merge flag-info {votes-against: (+ (get votes-against flag-info) u1)})))
        (ok true)))

(define-public (resolve-flag (content-id uint))
    (let (
        (flag-info (unwrap! (map-get? content-flags content-id) ERR-NO-SUBSCRIPTION))
        (total-votes (+ (get votes-for flag-info) (get votes-against flag-info)))
        (current-status (default-to {hidden: false, strike-count: u0} (map-get? content-status content-id)))
    )
        (asserts! (not (get resolved flag-info)) ERR-VOTING-ENDED)
        (asserts! (>= stacks-block-height (get voting-ends flag-info)) ERR-VOTING-ENDED)
        (asserts! (>= total-votes MIN-VOTES-REQUIRED) ERR-NOT-AUTHORIZED)
        
        (map-set content-flags content-id
            (merge flag-info {resolved: true}))
        
        (if (> (get votes-for flag-info) (get votes-against flag-info))
            (map-set content-status content-id
                {hidden: true, strike-count: (+ (get strike-count current-status) u1)})
            (map-set content-status content-id current-status))
        (ok true)))

(define-read-only (get-moderator-info (moderator principal))
    (map-get? moderators moderator))

(define-read-only (get-flag-info (content-id uint))
    (map-get? content-flags content-id))

(define-read-only (get-content-status (content-id uint))
    (map-get? content-status content-id))

(define-read-only (is-content-hidden (content-id uint))
    (match (map-get? content-status content-id)
        status (get hidden status)
        false))

(define-public (update-moderator-reputation (moderator principal) (new-reputation uint))
    (let ((mod-info (unwrap! (map-get? moderators moderator) ERR-NOT-MODERATOR)))
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set moderators
            moderator
            (merge mod-info {reputation: new-reputation})))))


(define-read-only (get-news-safe (id uint))
    (let ((news (unwrap! (map-get? news-content id) ERR-NO-SUBSCRIPTION))
          (user-sub (unwrap! (get-subscription-details tx-sender) ERR-NO-SUBSCRIPTION)))
        (asserts! (not (is-content-hidden id)) ERR-NOT-AUTHORIZED)
        (asserts! (can-access-tier (get tier news) (get tier user-sub)) ERR-NOT-AUTHORIZED)
        (ok news)))


