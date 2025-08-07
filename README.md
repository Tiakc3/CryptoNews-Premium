 
# CryptoNews Premium

A decentralized platform providing tiered access to verified crypto news, expert analysis, and market insights built on Stacks blockchain.

## Overview

CryptoNews Premium delivers curated cryptocurrency news and analysis through a tiered subscription model powered by smart contracts. Users can access different levels of exclusive content based on their subscription tier.

## Features

- **Tiered Subscription System**
  - Basic Tier: Entry level news access (100 STX)
  - Pro Tier: Advanced analysis + Basic features (500 STX) 
  - Elite Tier: Full platform access including trading signals (1000 STX)

- **Smart Contract Security**
  - Automated subscription management
  - Secure payment processing
  - Role-based access control
  - Transparent content delivery

## Technical Architecture

The platform is built using:
- Clarity smart contracts
- Stacks blockchain
- STX token for payments

### Core Smart Contract Functions

**Public Functions:**
- `subscribe-to-tier`: Purchase a subscription tier
- `add-news`: Add new content (admin only)
- `get-subscription-details`: View subscription status
- `get-news`: Access tier-appropriate content

## Getting Started

### Prerequisites
- Stacks wallet
- STX tokens for subscription
- Clarinet for development

### Local Development
1. Clone the repository
```bash
git clone https://github.com/Tiakc3/CryptoNews-Premium.git
