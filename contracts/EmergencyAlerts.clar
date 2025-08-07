;; Emergency Alert System for Breaking Crypto News
;; Real-time distribution of market-critical events with tier-based access

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INVALID-ALERT (err u301))
(define-constant ERR-ALREADY-ACKNOWLEDGED (err u302))
(define-constant ERR-NO-SUBSCRIPTION (err u303))
(define-constant ERR-INVALID-SEVERITY (err u304))
(define-constant ERR-ALERT-EXPIRED (err u305))
(define-constant ERR-INVALID-CATEGORY (err u306))

;; Alert system constants
(define-constant ALERT-EXPIRY-BLOCKS u1440) ;; ~10 days
(define-constant MAX-ALERT-MESSAGE-LENGTH u500)
(define-constant CRITICAL-ALERT-OVERRIDE true) ;; All tiers get critical alerts
(define-constant HIGH-PRIORITY-DELAY u0) ;; Elite gets immediate access
(define-constant MEDIUM-PRIORITY-DELAY u10) ;; Pro gets 10 block delay
(define-constant LOW-PRIORITY-DELAY u30) ;; Basic gets 30 block delay

;; Alert severity levels
(define-constant SEVERITY-CRITICAL u1)
(define-constant SEVERITY-HIGH u2)
(define-constant SEVERITY-MEDIUM u3)
(define-constant SEVERITY-LOW u4)

;; Alert categories
(define-constant CATEGORY-REGULATION "regulation")
(define-constant CATEGORY-EXCHANGE "exchange")
(define-constant CATEGORY-MARKET "market")
(define-constant CATEGORY-SECURITY "security")
(define-constant CATEGORY-PARTNERSHIP "partnership")

;; Data variables
(define-data-var alert-counter uint u0)
(define-data-var admin-address principal tx-sender)

;; Emergency alerts mapping
(define-map emergency-alerts
    uint ;; alert-id
    {title: (string-ascii 100),
     message: (string-ascii 500),
     category: (string-ascii 20),
     severity: uint,
     created-at: uint,
     expires-at: uint,
     min-tier-required: (string-ascii 20),
     author: principal,
     acknowledgment-count: uint,
     effectiveness-score: uint})

;; User alert acknowledgments
(define-map alert-acknowledgments
    {alert-id: uint, user: principal}
    {acknowledged-at: uint,
     response-time: uint}) ;; blocks between alert creation and acknowledgment

;; User alert preferences
(define-map user-alert-preferences
    principal
    {categories: (list 5 (string-ascii 20)),
     min-severity: uint,
     emergency-override: bool,
     notification-enabled: bool})

;; Alert distribution tracking
(define-map alert-distribution
    uint ;; alert-id
    {elite-sent: uint,
     pro-sent: uint,
     basic-sent: uint,
     total-eligible: uint,
     distribution-complete: bool})

;; Alert effectiveness metrics
(define-map alert-metrics
    uint ;; alert-id
    {total-views: uint,
     acknowledgment-rate: uint, ;; percentage
     avg-response-time: uint,
     market-impact-score: uint}) ;; to be set manually by admin

;; Category performance tracking
(define-map category-performance
    (string-ascii 20) ;; category
    {total-alerts: uint,
     avg-acknowledgment-rate: uint,
     avg-effectiveness: uint,
     last-updated: uint})

;; Public functions

;; Create emergency alert (admin only)
(define-public (create-emergency-alert 
    (title (string-ascii 100))
    (message (string-ascii 500))
    (category (string-ascii 20))
    (severity uint)
    (min-tier-required (string-ascii 20)))
    (let ((caller tx-sender)
          (alert-id (+ (var-get alert-counter) u1)))
        (asserts! (is-eq caller (var-get admin-address)) ERR-NOT-AUTHORIZED)
        (asserts! (and (>= severity SEVERITY-CRITICAL) (<= severity SEVERITY-LOW)) ERR-INVALID-SEVERITY)
        (asserts! (is-valid-category category) ERR-INVALID-CATEGORY)
        
        (var-set alert-counter alert-id)
        
        ;; Create the alert
        (map-set emergency-alerts
            alert-id
            {title: title,
             message: message,
             category: category,
             severity: severity,
             created-at: stacks-block-height,
             expires-at: (+ stacks-block-height ALERT-EXPIRY-BLOCKS),
             min-tier-required: min-tier-required,
             author: caller,
             acknowledgment-count: u0,
             effectiveness-score: u0})
        
        ;; Initialize distribution tracking
        (map-set alert-distribution
            alert-id
            {elite-sent: u0,
             pro-sent: u0,
             basic-sent: u0,
             total-eligible: u0,
             distribution-complete: false})
        
        ;; Initialize metrics
        (map-set alert-metrics
            alert-id
            {total-views: u0,
             acknowledgment-rate: u0,
             avg-response-time: u0,
             market-impact-score: u0})
        
        ;; Update category performance
        (update-category-stats category)
        (ok alert-id)))

;; Acknowledge alert receipt (subscribers only)
(define-public (acknowledge-alert (alert-id uint))
    (let ((caller tx-sender)
          (alert (unwrap! (map-get? emergency-alerts alert-id) ERR-INVALID-ALERT))
          (ack-key {alert-id: alert-id, user: caller}))
        
        ;; Check if user has valid subscription (integrate with main contract)
        (asserts! (has-valid-subscription caller) ERR-NO-SUBSCRIPTION)
        (asserts! (< stacks-block-height (get expires-at alert)) ERR-ALERT-EXPIRED)
        (asserts! (is-none (map-get? alert-acknowledgments ack-key)) ERR-ALREADY-ACKNOWLEDGED)
        
        (let ((response-time (- stacks-block-height (get created-at alert))))
            ;; Record acknowledgment
            (map-set alert-acknowledgments ack-key
                {acknowledged-at: stacks-block-height,
                 response-time: response-time})
            
            ;; Update alert acknowledgment count
            (map-set emergency-alerts alert-id
                (merge alert {acknowledgment-count: (+ (get acknowledgment-count alert) u1)}))
            
            ;; Update metrics
            (update-alert-metrics alert-id)
            (ok true))))

;; Set user alert preferences
(define-public (set-alert-preferences 
    (categories (list 5 (string-ascii 20)))
    (min-severity uint)
    (emergency-override bool)
    (notification-enabled bool))
    (let ((caller tx-sender))
        (asserts! (has-valid-subscription caller) ERR-NO-SUBSCRIPTION)
        (asserts! (and (>= min-severity SEVERITY-CRITICAL) (<= min-severity SEVERITY-LOW)) ERR-INVALID-SEVERITY)
        
        (ok (map-set user-alert-preferences
            caller
            {categories: categories,
             min-severity: min-severity,
             emergency-override: emergency-override,
             notification-enabled: notification-enabled}))))

;; Mark alert distribution as complete (admin only)
(define-public (complete-alert-distribution (alert-id uint) (total-eligible uint))
    (let ((caller tx-sender)
          (distribution (unwrap! (map-get? alert-distribution alert-id) ERR-INVALID-ALERT)))
        (asserts! (is-eq caller (var-get admin-address)) ERR-NOT-AUTHORIZED)
        
        (ok (map-set alert-distribution alert-id
            (merge distribution 
                {total-eligible: total-eligible,
                 distribution-complete: true})))))

;; Update market impact score (admin only)
(define-public (set-market-impact-score (alert-id uint) (impact-score uint))
    (let ((caller tx-sender)
          (metrics (unwrap! (map-get? alert-metrics alert-id) ERR-INVALID-ALERT)))
        (asserts! (is-eq caller (var-get admin-address)) ERR-NOT-AUTHORIZED)
        (asserts! (<= impact-score u100) ERR-INVALID-ALERT)
        
        (ok (map-set alert-metrics alert-id
            (merge metrics {market-impact-score: impact-score})))))

;; Increment alert view count
(define-public (record-alert-view (alert-id uint))
    (let ((caller tx-sender)
          (metrics (unwrap! (map-get? alert-metrics alert-id) ERR-INVALID-ALERT)))
        (asserts! (has-valid-subscription caller) ERR-NO-SUBSCRIPTION)
        
        (ok (map-set alert-metrics alert-id
            (merge metrics {total-views: (+ (get total-views metrics) u1)})))))

;; Admin function to change admin address
(define-public (set-admin (new-admin principal))
    (let ((caller tx-sender))
        (asserts! (is-eq caller (var-get admin-address)) ERR-NOT-AUTHORIZED)
        (var-set admin-address new-admin)
        (ok true)))

;; Read-only functions

(define-read-only (get-alert-details (alert-id uint))
    (map-get? emergency-alerts alert-id))

(define-read-only (get-user-preferences (user principal))
    (map-get? user-alert-preferences user))

(define-read-only (get-alert-acknowledgment (alert-id uint) (user principal))
    (map-get? alert-acknowledgments {alert-id: alert-id, user: user}))

(define-read-only (get-alert-distribution (alert-id uint))
    (map-get? alert-distribution alert-id))

(define-read-only (get-alert-metrics (alert-id uint))
    (map-get? alert-metrics alert-id))

(define-read-only (get-category-performance (category (string-ascii 20)))
    (map-get? category-performance category))

(define-read-only (is-alert-active (alert-id uint))
    (match (map-get? emergency-alerts alert-id)
        alert (< stacks-block-height (get expires-at alert))
        false))

(define-read-only (can-user-access-alert (alert-id uint) (user principal))
    (match (map-get? emergency-alerts alert-id)
        alert 
        (let ((user-tier (get-user-tier user))
              (required-tier (get min-tier-required alert))
              (alert-severity (get severity alert)))
            (or 
                ;; Critical alerts override tier requirements
                (and (is-eq alert-severity SEVERITY-CRITICAL) CRITICAL-ALERT-OVERRIDE)
                ;; Check if user tier can access this alert
                (can-tier-access-alert user-tier required-tier)))
        false))

(define-read-only (get-alert-count)
    (var-get alert-counter))

(define-read-only (get-admin-address)
    (var-get admin-address))

;; Private helper functions

(define-private (is-valid-category (category (string-ascii 20)))
    (or (is-eq category CATEGORY-REGULATION)
        (is-eq category CATEGORY-EXCHANGE)
        (is-eq category CATEGORY-MARKET)
        (is-eq category CATEGORY-SECURITY)
        (is-eq category CATEGORY-PARTNERSHIP)))

(define-private (has-valid-subscription (user principal))
    ;; This would integrate with the main CryptoNews contract
    ;; For now, we'll assume all users have valid subscriptions
    true)

(define-private (get-user-tier (user principal))
    ;; This would integrate with the main CryptoNews contract to get user tier
    ;; For now, return a default tier
    "basic")

(define-private (can-tier-access-alert (user-tier (string-ascii 20)) (required-tier (string-ascii 20)))
    (if (is-eq user-tier "elite")
        true
        (if (is-eq user-tier "pro")
            (or (is-eq required-tier "pro") (is-eq required-tier "basic"))
            (if (is-eq user-tier "basic")
                (is-eq required-tier "basic")
                false))))

(define-private (update-alert-metrics (alert-id uint))
    (match (map-get? emergency-alerts alert-id)
        alert
        (match (map-get? alert-metrics alert-id)
            current-metrics
            (match (map-get? alert-distribution alert-id)
                distribution
                (begin
                    ;; Calculate acknowledgment rate if distribution is complete
                    (if (get distribution-complete distribution)
                        (let ((ack-rate (if (> (get total-eligible distribution) u0)
                                           (/ (* (get acknowledgment-count alert) u100) (get total-eligible distribution))
                                           u0)))
                            (map-set alert-metrics alert-id
                                (merge current-metrics {acknowledgment-rate: ack-rate}))
                            true)
                        true))
                false)
            false)
        false))

(define-private (update-category-stats (category (string-ascii 20)))
    (let ((current-stats (default-to 
                           {total-alerts: u0, avg-acknowledgment-rate: u0, avg-effectiveness: u0, last-updated: u0}
                           (map-get? category-performance category))))
        (map-set category-performance category
            (merge current-stats 
                {total-alerts: (+ (get total-alerts current-stats) u1),
                 last-updated: stacks-block-height}))
        true))


