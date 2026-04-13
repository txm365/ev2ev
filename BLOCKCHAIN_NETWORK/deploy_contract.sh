#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# EV2EV — Smart Contract Deploy Script
# Compiles and deploys EnergyEscrow.sol to your local Hardhat node,
# then automatically patches the contract address into wallet_service.dart
#
# Usage:
#   chmod +x deploy_contract.sh && ./deploy_contract.sh
#
# Prerequisites:
#   - Hardhat node running: npx hardhat node   (in ~/hardhat-ev2ev)
#   - setup_hardhat.sh has been run
# ─────────────────────────────────────────────────────────────────────────────

set -e

GREEN='\033[0;32m'
AMBER='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[info]${RESET}  $1"; }
success() { echo -e "${GREEN}[done]${RESET}  $1"; }
warn()    { echo -e "${AMBER}[warn]${RESET}  $1"; }
error()   { echo -e "${RED}[error]${RESET} $1"; exit 1; }
step()    { echo -e "\n${BOLD}━━━  $1  ━━━${RESET}"; }

HARDHAT_DIR="$HOME/hardhat-ev2ev"
FLUTTER_DIR="$HOME/Desktop/PROJECT FINAL"
WALLET_SERVICE="$FLUTTER_DIR/lib/services/wallet_service.dart"
CONTRACT_SRC="$FLUTTER_DIR/EnergyEscrow.sol"

# ─────────────────────────────────────────────────────────────────────────────
step "Step 1 — Checking Hardhat project"
# ─────────────────────────────────────────────────────────────────────────────

[ -d "$HARDHAT_DIR" ] || error "Hardhat folder not found at $HARDHAT_DIR — run setup_hardhat.sh first"
[ -f "$HARDHAT_DIR/hardhat.config.cjs" ] || [ -f "$HARDHAT_DIR/hardhat.config.js" ] || error "hardhat.config.cjs missing — run setup_hardhat.sh first"
success "Hardhat project found at $HARDHAT_DIR"

# ─────────────────────────────────────────────────────────────────────────────
step "Step 2 — Checking Hardhat node is running"
# ─────────────────────────────────────────────────────────────────────────────

if curl -s -X POST http://127.0.0.1:8545 \
   -H "Content-Type: application/json" \
   -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   --max-time 3 | grep -q "result"; then
  success "Hardhat node is running on http://127.0.0.1:8545"
else
  error "Hardhat node is NOT running.\nOpen a separate terminal and run:\n  cd $HARDHAT_DIR && npx hardhat node"
fi

# ─────────────────────────────────────────────────────────────────────────────
step "Step 3 — Copying contract to Hardhat"
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$HARDHAT_DIR/contracts"

if [ -f "$CONTRACT_SRC" ]; then
  cp "$CONTRACT_SRC" "$HARDHAT_DIR/contracts/EnergyEscrow.sol"
  success "EnergyEscrow.sol copied from Flutter project"
elif [ -f "$HARDHAT_DIR/contracts/EnergyEscrow.sol" ]; then
  success "EnergyEscrow.sol already in Hardhat contracts folder"
else
  error "EnergyEscrow.sol not found.\nExpected at: $CONTRACT_SRC\nPlace it there and re-run."
fi

# ─────────────────────────────────────────────────────────────────────────────
step "Step 4 — Writing deploy script"
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$HARDHAT_DIR/scripts"

cat > "$HARDHAT_DIR/scripts/deploy.mjs" << 'DEPLOY'
import hre from "hardhat";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const balance    = await deployer.provider.getBalance(deployer.address);

  console.log("\n Deployer : " + deployer.address);
  console.log(" Balance  : " + hre.ethers.formatEther(balance) + " ETH\n");

  const Factory = await hre.ethers.getContractFactory("EnergyEscrow");
  console.log(" Deploying EnergyEscrow...");
  const contract = await Factory.deploy();
  await contract.waitForDeployment();

  const address = await contract.getAddress();

  console.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log(" Contract address : " + address);
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  // Write address to a temp file so the shell script can read it
  fs.writeFileSync(
    path.join(__dirname, "..", ".last_deploy_address"),
    address
  );
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
DEPLOY

success "deploy.js written"

# ─────────────────────────────────────────────────────────────────────────────
step "Step 5 — Compiling contract"
# ─────────────────────────────────────────────────────────────────────────────

cd "$HARDHAT_DIR"
info "Running: npx hardhat compile"
npx hardhat compile
success "Compilation successful"

# ─────────────────────────────────────────────────────────────────────────────
step "Step 6 — Deploying to localhost"
# ─────────────────────────────────────────────────────────────────────────────

info "Deploying to http://127.0.0.1:8545 (chain ID 31337)..."
npx hardhat run scripts/deploy.mjs --network localhost

# Read the deployed address
ADDRESS_FILE="$HARDHAT_DIR/.last_deploy_address"
if [ ! -f "$ADDRESS_FILE" ]; then
  error "Deploy script did not write address file — check for errors above"
fi

CONTRACT_ADDRESS=$(cat "$ADDRESS_FILE")
[ -n "$CONTRACT_ADDRESS" ] || error "Empty contract address — deploy may have failed"
success "Deployed at: $CONTRACT_ADDRESS"

# ─────────────────────────────────────────────────────────────────────────────
step "Step 7 — Patching wallet_service.dart"
# ─────────────────────────────────────────────────────────────────────────────

if [ ! -f "$WALLET_SERVICE" ]; then
  warn "wallet_service.dart not found at $WALLET_SERVICE"
  warn "Manually set contractAddress to: $CONTRACT_ADDRESS"
else
  # Replace the contractAddress line
  # Handles both '0x0000...' placeholder and any previous address
  # Use python to safely replace multi-line contractAddress declaration
  python3 -c "
import re, sys
with open('$WALLET_SERVICE', 'r') as f: content = f.read()
content = re.sub(
    r\"static const String contractAddress =\s*'[^']*';\",
    \"static const String contractAddress = '$CONTRACT_ADDRESS'; // auto-patched\",
    content
)
with open('$WALLET_SERVICE', 'w') as f: f.write(content)
"

  # Verify it was patched
  if grep -q "$CONTRACT_ADDRESS" "$WALLET_SERVICE"; then
    success "wallet_service.dart patched successfully"
  else
    warn "Could not auto-patch — set contractAddress manually to: $CONTRACT_ADDRESS"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
step "Step 8 — Verifying deployment"
# ─────────────────────────────────────────────────────────────────────────────

BYTECODE=$(curl -s -X POST http://127.0.0.1:8545 \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$CONTRACT_ADDRESS\",\"latest\"],\"id\":1}" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'])" 2>/dev/null)

if [ "$BYTECODE" != "0x" ] && [ -n "$BYTECODE" ]; then
  success "Contract bytecode confirmed on-chain"
else
  warn "Could not verify bytecode — contract may not be deployed correctly"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}${BOLD}  Deployment complete!${RESET}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  Contract address : ${BOLD}$CONTRACT_ADDRESS${RESET}"
echo -e "  Network          : Hardhat Local (chain ID 31337)"
echo -e "  wallet_service.dart : auto-patched"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
echo -e "  1. Hot-restart the Flutter app (r in terminal / save any file)"
echo -e "  2. In the app: Switch Accounts → select Hardhat Local"
echo -e "  3. Import Account #0 if not done:"
echo -e "     ${BOLD}test test test test test test test test test test test junk${RESET}"
echo -e "  4. Try a payment — funds settle instantly on local chain"
echo ""
echo -e "  ${AMBER}Note:${RESET} Hardhat resets on restart — re-run this script each session"
echo ""