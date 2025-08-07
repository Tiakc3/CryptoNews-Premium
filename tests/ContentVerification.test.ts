// import { describe, expect, it } from "vitest";

// const accounts = simnet.getAccounts();
// const deployer = accounts.get("deployer")!;
// const factChecker1 = accounts.get("wallet_1")!;
// const factChecker2 = accounts.get("wallet_2")!;
// const factChecker3 = accounts.get("wallet_3")!;
// const source = accounts.get("wallet_4")!;

// describe("ContentVerification Tests", () => {
//   it("can register as fact-checker", () => {
//     const { result } = simnet.callPublicFn(
//       "ContentVerification", 
//       "register-fact-checker", 
//       [], 
//       factChecker1
//     );
//     expect(result).toBeOk(true);
//   });

//   it("can register verified source", () => {
//     const { result } = simnet.callPublicFn(
//       "ContentVerification", 
//       "register-source", 
//       [`"CryptoNews"`, `"cryptonews.com"`], 
//       source
//     );
//     expect(result).toBeOk(true);
//   });

//   it("fact-checker can verify content", () => {
//     simnet.callPublicFn(
//       "ContentVerification", 
//       "register-fact-checker", 
//       [], 
//       factChecker1
//     );
    
//     simnet.callPublicFn(
//       "ContentVerification", 
//       "register-source", 
//       [`"CryptoNews"`, `"cryptonews.com"`], 
//       source
//     );

//     const { result } = simnet.callPublicFn(
//       "ContentVerification", 
//       "verify-content", 
//       [`u1`, source, `u85`], 
//       factChecker1
//     );
//     expect(result).toBeOk(`u1`);
//   });

//   it("can challenge verification", () => {
//     simnet.callPublicFn("ContentVerification", "register-fact-checker", [], factChecker1);
//     simnet.callPublicFn("ContentVerification", "register-fact-checker", [], factChecker2);
//     simnet.callPublicFn("ContentVerification", "register-source", [`"CryptoNews"`, `"cryptonews.com"`], source);
//     simnet.callPublicFn("ContentVerification", "verify-content", [`u1`, source, `u85`], factChecker1);

//     const { result } = simnet.callPublicFn(
//       "ContentVerification", 
//       "challenge-verification", 
//       [`u1`, `"Inaccurate information"`], 
//       factChecker2
//     );
//     expect(result).toBeOk(`u1`);
//   });

//   it("can vote on verification challenge", () => {
//     simnet.callPublicFn("ContentVerification", "register-fact-checker", [], factChecker1);
//     simnet.callPublicFn("ContentVerification", "register-fact-checker", [], factChecker2);
//     simnet.callPublicFn("ContentVerification", "register-fact-checker", [], factChecker3);
//     simnet.callPublicFn("ContentVerification", "register-source", [`"CryptoNews"`, `"cryptonews.com"`], source);
//     simnet.callPublicFn("ContentVerification", "verify-content", [`u1`, source, `u85`], factChecker1);
//     simnet.callPublicFn("ContentVerification", "challenge-verification", [`u1`, `"Inaccurate information"`], factChecker2);

//     const { result } = simnet.callPublicFn(
//       "ContentVerification", 
//       "vote-on-challenge", 
//       [`u1`, `false`], 
//       factChecker3
//     );
//     expect(result).toBeOk(true);
//   });

//   it("can get source credibility badge", () => {
//     simnet.callPublicFn("ContentVerification", "register-source", [`"CryptoNews"`, `"cryptonews.com"`], source);

//     const { result } = simnet.callReadOnlyFn(
//       "ContentVerification",
//       "get-credibility-badge",
//       [source],
//       deployer
//     );
//     expect(result).toBeAscii("bronze");
//   });

//   it("can add content citations", () => {
//     simnet.callPublicFn("ContentVerification", "register-fact-checker", [], factChecker1);

//     const { result } = simnet.callPublicFn(
//       "ContentVerification", 
//       "add-content-citations", 
//       [`u1`, `["coindesk.com", "cointelegraph.com"]`, `["reddit.com", "twitter.com"]`], 
//       factChecker1
//     );
//     expect(result).toBeOk(true);
//   });

//   it("cannot verify content without being fact-checker", () => {
//     simnet.callPublicFn("ContentVerification", "register-source", [`"CryptoNews"`, `"cryptonews.com"`], source);

//     const { result } = simnet.callPublicFn(
//       "ContentVerification", 
//       "verify-content", 
//       [`u1`, source, `u85`], 
//       deployer
//     );
//     expect(result).toBeErr(`u200`);
//   });

//   it("cannot register same source twice", () => {
//     simnet.callPublicFn("ContentVerification", "register-source", [`"CryptoNews"`, `"cryptonews.com"`], source);
    
//     const { result } = simnet.callPublicFn(
//       "ContentVerification", 
//       "register-source", 
//       [`"Another Name"`, `"anotherdomain.com"`], 
//       source
//     );
//     expect(result).toBeErr(`u206`);
//   });

//   it("can check if content is verified", () => {
//     simnet.callPublicFn("ContentVerification", "register-fact-checker", [], factChecker1);
//     simnet.callPublicFn("ContentVerification", "register-source", [`"CryptoNews"`, `"cryptonews.com"`], source);
//     simnet.callPublicFn("ContentVerification", "verify-content", [`u1`, source, `u85`], factChecker1);

//     const verifiedResult = simnet.callReadOnlyFn(
//       "ContentVerification",
//       "is-content-verified",
//       [`u1`],
//       deployer
//     );
//     expect(verifiedResult.result).toBeBool(true);

//     const unverifiedResult = simnet.callReadOnlyFn(
//       "ContentVerification",
//       "is-content-verified",
//       [`u999`],
//       deployer
//     );
//     expect(unverifiedResult.result).toBeBool(false);
//   });
// });
