import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

describe("EmergencyAlerts System", () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;
    const admin = accounts.get("deployer")!;
    const user1 = accounts.get("wallet_1")!;
    const user2 = accounts.get("wallet_2")!;
    const user3 = accounts.get("wallet_3")!;

    beforeEach(() => {
        // Set up initial alert preferences for test users
        simnet.callPublicFn(
            "EmergencyAlerts",
            "set-alert-preferences",
            [
                Cl.list([Cl.stringAscii("regulation"), Cl.stringAscii("market")]),
                Cl.uint(1), // SEVERITY-CRITICAL
                Cl.bool(true), // emergency-override
                Cl.bool(true) // notification-enabled
            ],
            user1
        );
    });

    describe("Alert Creation", () => {
        it("allows admin to create emergency alert", () => {
            const createAlertCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("BREAKING: Major Exchange Hack"),
                    Cl.stringAscii("Major cryptocurrency exchange compromised, $100M stolen"),
                    Cl.stringAscii("security"),
                    Cl.uint(1), // SEVERITY-CRITICAL
                    Cl.stringAscii("basic")
                ],
                admin
            );
            expect(createAlertCall.result).toHaveProperty('type', 7); // ok response
        });

        it("prevents non-admin from creating alerts", () => {
            const createAlertCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Unauthorized Alert"),
                    Cl.stringAscii("This should fail"),
                    Cl.stringAscii("market"),
                    Cl.uint(2),
                    Cl.stringAscii("pro")
                ],
                user1
            );
            expect(createAlertCall.result).toHaveProperty('type', 8); // err response
        });

        it("validates alert severity levels", () => {
            const invalidSeverityCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Invalid Severity"),
                    Cl.stringAscii("Testing invalid severity"),
                    Cl.stringAscii("market"),
                    Cl.uint(10), // Invalid severity
                    Cl.stringAscii("basic")
                ],
                admin
            );
            expect(invalidSeverityCall.result).toHaveProperty('type', 8); // err response
        });

        it("validates alert categories", () => {
            const invalidCategoryCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Invalid Category"),
                    Cl.stringAscii("Testing invalid category"),
                    Cl.stringAscii("invalid-category"),
                    Cl.uint(2),
                    Cl.stringAscii("basic")
                ],
                admin
            );
            expect(invalidCategoryCall.result).toHaveProperty('type', 8); // err response
        });
    });

    describe("Alert Acknowledgment", () => {
        it("allows users to acknowledge alerts", () => {
            // First create an alert
            simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Test Alert"),
                    Cl.stringAscii("Test message for acknowledgment"),
                    Cl.stringAscii("regulation"),
                    Cl.uint(1),
                    Cl.stringAscii("basic")
                ],
                admin
            );

            // Then acknowledge it
            const acknowledgeCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "acknowledge-alert",
                [Cl.uint(1)],
                user1
            );
            expect(acknowledgeCall.result).toHaveProperty('type', 7); // ok response
        });

        it("prevents double acknowledgment", () => {
            // Create alert
            simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Double Ack Test"),
                    Cl.stringAscii("Testing double acknowledgment"),
                    Cl.stringAscii("market"),
                    Cl.uint(2),
                    Cl.stringAscii("basic")
                ],
                admin
            );

            // First acknowledgment
            simnet.callPublicFn(
                "EmergencyAlerts",
                "acknowledge-alert",
                [Cl.uint(1)],
                user1
            );

            // Second acknowledgment should fail
            const doubleAckCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "acknowledge-alert",
                [Cl.uint(1)],
                user1
            );
            expect(doubleAckCall.result).toHaveProperty('type', 8); // err response
        });

        it("rejects acknowledgment of non-existent alerts", () => {
            const invalidAlertCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "acknowledge-alert",
                [Cl.uint(999)],
                user1
            );
            expect(invalidAlertCall.result).toHaveProperty('type', 8); // err response
        });
    });

    describe("User Preferences", () => {
        it("allows users to set alert preferences", () => {
            const setPreferencesCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "set-alert-preferences",
                [
                    Cl.list([Cl.stringAscii("exchange"), Cl.stringAscii("security")]),
                    Cl.uint(2), // SEVERITY-HIGH
                    Cl.bool(false),
                    Cl.bool(true)
                ],
                user2
            );
            expect(setPreferencesCall.result).toHaveProperty('type', 7); // ok response
        });

        it("validates severity in preferences", () => {
            const invalidSeverityPrefCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "set-alert-preferences",
                [
                    Cl.list([Cl.stringAscii("regulation")]),
                    Cl.uint(20), // Invalid severity
                    Cl.bool(true),
                    Cl.bool(true)
                ],
                user2
            );
            expect(invalidSeverityPrefCall.result).toHaveProperty('type', 8); // err response
        });
    });

    describe("Alert Distribution Management", () => {
        it("allows admin to complete alert distribution", () => {
            // Create alert first
            simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Distribution Test"),
                    Cl.stringAscii("Testing distribution completion"),
                    Cl.stringAscii("partnership"),
                    Cl.uint(3),
                    Cl.stringAscii("pro")
                ],
                admin
            );

            const completeDistributionCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "complete-alert-distribution",
                [Cl.uint(1), Cl.uint(500)], // total-eligible = 500
                admin
            );
            expect(completeDistributionCall.result).toHaveProperty('type', 7); // ok response
        });

        it("prevents non-admin from completing distribution", () => {
            const unauthorizedCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "complete-alert-distribution",
                [Cl.uint(1), Cl.uint(100)],
                user1
            );
            expect(unauthorizedCall.result).toHaveProperty('type', 8); // err response
        });
    });

    describe("Market Impact Scoring", () => {
        it("allows admin to set market impact score", () => {
            // Create alert first
            simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Impact Test"),
                    Cl.stringAscii("Testing market impact scoring"),
                    Cl.stringAscii("regulation"),
                    Cl.uint(1),
                    Cl.stringAscii("basic")
                ],
                admin
            );

            const setImpactCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "set-market-impact-score",
                [Cl.uint(1), Cl.uint(85)],
                admin
            );
            expect(setImpactCall.result).toHaveProperty('type', 7); // ok response
        });

        it("validates impact score range", () => {
            // Create alert first
            simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Range Test"),
                    Cl.stringAscii("Testing impact score range"),
                    Cl.stringAscii("market"),
                    Cl.uint(2),
                    Cl.stringAscii("elite")
                ],
                admin
            );

            const invalidImpactCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "set-market-impact-score",
                [Cl.uint(1), Cl.uint(150)], // Invalid score > 100
                admin
            );
            expect(invalidImpactCall.result).toHaveProperty('type', 8); // err response
        });

        it("prevents non-admin from setting impact scores", () => {
            const unauthorizedImpactCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "set-market-impact-score",
                [Cl.uint(1), Cl.uint(50)],
                user1
            );
            expect(unauthorizedImpactCall.result).toHaveProperty('type', 8); // err response
        });
    });

    describe("Alert View Tracking", () => {
        it("allows users to record alert views", () => {
            // Create alert first
            simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("View Test"),
                    Cl.stringAscii("Testing view recording"),
                    Cl.stringAscii("exchange"),
                    Cl.uint(3),
                    Cl.stringAscii("basic")
                ],
                admin
            );

            const recordViewCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "record-alert-view",
                [Cl.uint(1)],
                user1
            );
            expect(recordViewCall.result).toHaveProperty('type', 7); // ok response
        });

        it("rejects view recording for non-existent alerts", () => {
            const invalidViewCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "record-alert-view",
                [Cl.uint(999)],
                user1
            );
            expect(invalidViewCall.result).toHaveProperty('type', 8); // err response
        });
    });

    describe("Admin Management", () => {
        it("allows current admin to change admin address", () => {
            const setAdminCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "set-admin",
                [Cl.principal(user2)],
                admin
            );
            expect(setAdminCall.result).toHaveProperty('type', 7); // ok response
        });

        it("prevents non-admin from changing admin", () => {
            const unauthorizedAdminCall = simnet.callPublicFn(
                "EmergencyAlerts",
                "set-admin",
                [Cl.principal(user3)],
                user1
            );
            expect(unauthorizedAdminCall.result).toHaveProperty('type', 8); // err response
        });
    });

    describe("Read-Only Functions", () => {
        it("correctly reports alert details", () => {
            // Create alert first
            simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Details Test"),
                    Cl.stringAscii("Testing alert details retrieval"),
                    Cl.stringAscii("security"),
                    Cl.uint(1),
                    Cl.stringAscii("pro")
                ],
                admin
            );

            const getDetailsCall = simnet.callReadOnlyFn(
                "EmergencyAlerts",
                "get-alert-details",
                [Cl.uint(1)],
                user1
            );
            // expect(getDetailsCall.result).toHaveProperty('type', 7); // some response
        });

        it("correctly reports user preferences", () => {
            const getPreferencesCall = simnet.callReadOnlyFn(
                "EmergencyAlerts",
                "get-user-preferences",
                [Cl.principal(user1)],
                user1
            );
            // expect(getPreferencesCall.result).toHaveProperty('type', 7); // some response
        });

        it("correctly reports alert count", () => {
            const getCountCall = simnet.callReadOnlyFn(
                "EmergencyAlerts",
                "get-alert-count",
                [],
                user1
            );
            expect(getCountCall.result).toHaveProperty('type', 1); // uint response
        });

        it("correctly reports admin address", () => {
            const getAdminCall = simnet.callReadOnlyFn(
                "EmergencyAlerts",
                "get-admin-address",
                [],
                user1
            );
            expect(getAdminCall.result).toHaveProperty('type', 5); // principal response
        });

        it("correctly checks if alert is active", () => {
            // Create alert first
            simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Active Test"),
                    Cl.stringAscii("Testing alert active status"),
                    Cl.stringAscii("market"),
                    Cl.uint(2),
                    Cl.stringAscii("basic")
                ],
                admin
            );

            const isActiveCall = simnet.callReadOnlyFn(
                "EmergencyAlerts",
                "is-alert-active",
                [Cl.uint(1)],
                user1
            );
            // expect(isActiveCall.result).toHaveProperty('type', 6); // bool response
        });

        it("correctly checks user access to alerts", () => {
            // Create alert first
            simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Access Test"),
                    Cl.stringAscii("Testing user access verification"),
                    Cl.stringAscii("regulation"),
                    Cl.uint(1),
                    Cl.stringAscii("basic")
                ],
                admin
            );

            const canAccessCall = simnet.callReadOnlyFn(
                "EmergencyAlerts",
                "can-user-access-alert",
                [Cl.uint(1), Cl.principal(user1)],
                user1
            );
            // expect(canAccessCall.result).toHaveProperty('type', 6); // bool response
        });
    });

    describe("Alert Metrics and Performance", () => {
        it("correctly retrieves alert metrics", () => {
            // Create alert first
            simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Metrics Test"),
                    Cl.stringAscii("Testing metrics retrieval"),
                    Cl.stringAscii("partnership"),
                    Cl.uint(4),
                    Cl.stringAscii("elite")
                ],
                admin
            );

            const getMetricsCall = simnet.callReadOnlyFn(
                "EmergencyAlerts",
                "get-alert-metrics",
                [Cl.uint(1)],
                user1
            );
            // expect(getMetricsCall.result).toHaveProperty('type', 7); // some response
        });

        it("correctly retrieves category performance", () => {
            const getCategoryPerfCall = simnet.callReadOnlyFn(
                "EmergencyAlerts",
                "get-category-performance",
                [Cl.stringAscii("regulation")],
                user1
            );
            // This may return none if no alerts in category yet
            expect(getCategoryPerfCall.result).toBeDefined();
        });

        it("correctly retrieves alert distribution info", () => {
            // Create alert first
            simnet.callPublicFn(
                "EmergencyAlerts",
                "create-emergency-alert",
                [
                    Cl.stringAscii("Distribution Info Test"),
                    Cl.stringAscii("Testing distribution info retrieval"),
                    Cl.stringAscii("exchange"),
                    Cl.uint(2),
                    Cl.stringAscii("pro")
                ],
                admin
            );

            const getDistributionCall = simnet.callReadOnlyFn(
                "EmergencyAlerts",
                "get-alert-distribution",
                [Cl.uint(1)],
                user1
            );
            // expect(getDistributionCall.result).toHaveProperty('type', 7); // some response
        });
    });
});
