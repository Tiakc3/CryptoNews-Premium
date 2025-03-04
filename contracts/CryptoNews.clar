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
