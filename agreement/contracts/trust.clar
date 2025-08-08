;; TrustBridge
;; A decentralized work agreement platform with phase-based payment releases
;; Contract allows employers to create work agreements, contractors to accept them,
;; and implements a phase-based payment system with arbitration support

;; Constants
(define-constant contract-admin tx-sender)
(define-constant err-admin-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-wrong-status (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-invalid-percentage (err u106))
(define-constant err-invalid-input (err u107))

;; Agreement status types
(define-data-var agreement-id-counter uint u0)

;; Data Structures
(define-map work-agreements 
    { agreement-id: uint }
    {
        employer: principal,
        contractor: (optional principal),
        total-payment: uint,
        phase-count: uint,
        work-description: (string-utf8 500),
        current-status: (string-ascii 20),
        arbitrator: principal,
        created-block: uint
    }
)

(define-map work-phases
    { agreement-id: uint, phase-id: uint }
    {
        payment-amount: uint,
        phase-description: (string-utf8 256),
        phase-status: (string-ascii 20),
        delivery-proof: (optional (string-utf8 500))
    }
)

(define-map agreement-treasury
    { agreement-id: uint }
    { 
        current-balance: uint,
        total-released: uint
    }
)

(define-map arbitration-cases
    { agreement-id: uint }
    {
        initiated-by: principal,
        dispute-reason: (string-utf8 500),
        arbitration-fee: uint,
        case-resolved: bool
    }
)

;; Input validation functions
(define-private (is-valid-string-utf8 (input (string-utf8 500)))
    (> (len input) u0)
)

(define-private (is-valid-phase-description (input (string-utf8 256)))
    (> (len input) u0)
)

(define-private (is-valid-principal (input principal))
    (not (is-eq input 'SP000000000000000000002Q6VF78))
)

(define-private (is-valid-agreement-id (agreement-id uint))
    (and (> agreement-id u0) (<= agreement-id (var-get agreement-id-counter)))
)

;; Read-only functions
(define-read-only (get-agreement-info (agreement-id uint))
    (begin
        (asserts! (is-valid-agreement-id agreement-id) err-invalid-input)
        (ok (unwrap! (map-get? work-agreements {agreement-id: agreement-id}) err-not-found))
    )
)

(define-read-only (get-phase-info (agreement-id uint) (phase-id uint))
    (begin
        (asserts! (is-valid-agreement-id agreement-id) err-invalid-input)
        (ok (unwrap! (map-get? work-phases {agreement-id: agreement-id, phase-id: phase-id}) err-not-found))
    )
)

(define-read-only (get-treasury-info (agreement-id uint))
    (begin
        (asserts! (is-valid-agreement-id agreement-id) err-invalid-input)
        (ok (unwrap! (map-get? agreement-treasury {agreement-id: agreement-id}) err-not-found))
    )
)

;; Public functions
(define-public (create-work-agreement (work-description (string-utf8 500)) (total-payment uint) (phase-count uint) (arbitrator principal))
    (let
        (
            (agreement-id (+ (var-get agreement-id-counter) u1))
            (validated-description (begin (asserts! (is-valid-string-utf8 work-description) err-invalid-input) work-description))
            (validated-arbitrator (begin (asserts! (is-valid-principal arbitrator) err-invalid-input) arbitrator))
        )
        (asserts! (> total-payment u0) err-invalid-percentage)
        (asserts! (> phase-count u0) err-invalid-percentage)
        
        (try! (stx-transfer? total-payment tx-sender (as-contract tx-sender)))
        
        (map-set work-agreements
            {agreement-id: agreement-id}
            {
                employer: tx-sender,
                contractor: none,
                total-payment: total-payment,
                phase-count: phase-count,
                work-description: validated-description,
                current-status: "open",
                arbitrator: validated-arbitrator,
                created-block: block-height
            }
        )
        
        (map-set agreement-treasury
            {agreement-id: agreement-id}
            {
                current-balance: total-payment,
                total-released: u0
            }
        )
        
        (var-set agreement-id-counter agreement-id)
        (ok agreement-id)
    )
)

(define-public (accept-work-agreement (agreement-id uint))
    (let
        (
            (validated-id (begin (asserts! (is-valid-agreement-id agreement-id) err-invalid-input) agreement-id))
            (agreement (unwrap! (map-get? work-agreements {agreement-id: validated-id}) err-not-found))
        )
        (asserts! (is-eq (get current-status agreement) "open") err-wrong-status)
        (asserts! (is-none (get contractor agreement)) err-already-exists)
        
        (map-set work-agreements
            {agreement-id: validated-id}
            (merge agreement {
                contractor: (some tx-sender),
                current-status: "in-progress"
            })
        )
        (ok true)
    )
)

(define-public (submit-phase-delivery (agreement-id uint) (phase-id uint) (delivery-proof (string-utf8 500)))
    (let
        (
            (validated-agreement-id (begin (asserts! (is-valid-agreement-id agreement-id) err-invalid-input) agreement-id))
            (validated-delivery-proof (begin (asserts! (is-valid-string-utf8 delivery-proof) err-invalid-input) delivery-proof))
            (agreement (unwrap! (map-get? work-agreements {agreement-id: validated-agreement-id}) err-not-found))
            (phase (unwrap! (map-get? work-phases {agreement-id: validated-agreement-id, phase-id: phase-id}) err-not-found))
        )
        (asserts! (is-eq (some tx-sender) (get contractor agreement)) err-unauthorized)
        (asserts! (is-eq (get phase-status phase) "pending") err-wrong-status)
        
        (map-set work-phases
            {agreement-id: validated-agreement-id, phase-id: phase-id}
            (merge phase {
                phase-status: "submitted",
                delivery-proof: (some validated-delivery-proof)
            })
        )
        (ok true)
    )
)

(define-public (approve-phase-delivery (agreement-id uint) (phase-id uint))
    (let
        (
            (validated-agreement-id (begin (asserts! (is-valid-agreement-id agreement-id) err-invalid-input) agreement-id))
            (agreement (unwrap! (map-get? work-agreements {agreement-id: validated-agreement-id}) err-not-found))
            (phase (unwrap! (map-get? work-phases {agreement-id: validated-agreement-id, phase-id: phase-id}) err-not-found))
            (treasury (unwrap! (map-get? agreement-treasury {agreement-id: validated-agreement-id}) err-not-found))
        )
        (asserts! (is-eq tx-sender (get employer agreement)) err-unauthorized)
        (asserts! (is-eq (get phase-status phase) "submitted") err-wrong-status)
        
        ;; Release payment
        (try! (as-contract (stx-transfer? 
            (get payment-amount phase)
            tx-sender
            (unwrap! (get contractor agreement) err-not-found)
        )))
        
        ;; Update phase and treasury
        (map-set work-phases
            {agreement-id: validated-agreement-id, phase-id: phase-id}
            (merge phase {phase-status: "completed"})
        )
        
        (map-set agreement-treasury
            {agreement-id: validated-agreement-id}
            {
                current-balance: (- (get current-balance treasury) (get payment-amount phase)),
                total-released: (+ (get total-released treasury) (get payment-amount phase))
            }
        )
        
        (ok true)
    )
)

(define-public (initiate-arbitration (agreement-id uint) (dispute-reason (string-utf8 500)))
    (let
        (
            (validated-agreement-id (begin (asserts! (is-valid-agreement-id agreement-id) err-invalid-input) agreement-id))
            (validated-dispute-reason (begin (asserts! (is-valid-string-utf8 dispute-reason) err-invalid-input) dispute-reason))
            (agreement (unwrap! (map-get? work-agreements {agreement-id: validated-agreement-id}) err-not-found))
            (arbitration-fee (/ (get total-payment agreement) u20))
        )
        (asserts! (or 
            (is-eq tx-sender (get employer agreement))
            (is-eq (some tx-sender) (get contractor agreement))
        ) err-unauthorized)
        
        (map-set arbitration-cases
            {agreement-id: validated-agreement-id}
            {
                initiated-by: tx-sender,
                dispute-reason: validated-dispute-reason,
                arbitration-fee: arbitration-fee,
                case-resolved: false
            }
        )
        
        (map-set work-agreements
            {agreement-id: validated-agreement-id}
            (merge agreement {current-status: "disputed"})
        )
        
        (ok true)
    )
)

(define-public (resolve-arbitration-case 
    (agreement-id uint) 
    (employer-percentage uint)
    (contractor-percentage uint))
    (let
        (
            (validated-agreement-id (begin (asserts! (is-valid-agreement-id agreement-id) err-invalid-input) agreement-id))
            (agreement (unwrap! (map-get? work-agreements {agreement-id: validated-agreement-id}) err-not-found))
            (treasury (unwrap! (map-get? agreement-treasury {agreement-id: validated-agreement-id}) err-not-found))
            (arbitration-case (unwrap! (map-get? arbitration-cases {agreement-id: validated-agreement-id}) err-not-found))
        )
        (asserts! (is-eq tx-sender (get arbitrator agreement)) err-unauthorized)
        (asserts! (is-eq (+ employer-percentage contractor-percentage) u100) err-invalid-percentage)
        
        ;; Calculate amounts
        (let
            (
                (remaining-balance (get current-balance treasury))
                (employer-amount (/ (* remaining-balance employer-percentage) u100))
                (contractor-amount (/ (* remaining-balance contractor-percentage) u100))
            )
            ;; Transfer funds
            (try! (as-contract (stx-transfer? employer-amount tx-sender (get employer agreement))))
            (try! (as-contract (stx-transfer? contractor-amount tx-sender (unwrap! (get contractor agreement) err-not-found))))
            (try! (as-contract (stx-transfer? (get arbitration-fee arbitration-case) tx-sender (get arbitrator agreement))))
            
            ;; Update agreement status
            (map-set work-agreements
                {agreement-id: validated-agreement-id}
                (merge agreement {current-status: "resolved"})
            )
            
            (map-set arbitration-cases
                {agreement-id: validated-agreement-id}
                (merge arbitration-case {case-resolved: true})
            )
            
            (ok true)
        )
    )
)

;; Initialize work phase
(define-public (define-work-phase 
    (agreement-id uint) 
    (phase-id uint)
    (payment-amount uint)
    (phase-description (string-utf8 256)))
    (let
        (
            (validated-agreement-id (begin (asserts! (is-valid-agreement-id agreement-id) err-invalid-input) agreement-id))
            (validated-payment-amount (begin (asserts! (> payment-amount u0) err-invalid-input) payment-amount))
            (validated-phase-description (begin (asserts! (is-valid-phase-description phase-description) err-invalid-input) phase-description))
            (agreement (unwrap! (map-get? work-agreements {agreement-id: validated-agreement-id}) err-not-found))
        )
        (asserts! (is-eq tx-sender (get employer agreement)) err-unauthorized)
        (asserts! (< phase-id (get phase-count agreement)) err-invalid-percentage)
        
        (map-set work-phases
            {agreement-id: validated-agreement-id, phase-id: phase-id}
            {
                payment-amount: validated-payment-amount,
                phase-description: validated-phase-description,
                phase-status: "pending",
                delivery-proof: none
            }
        )
        (ok true)
    )
)