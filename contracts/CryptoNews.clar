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
