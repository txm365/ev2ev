#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# EV2EV — Hardhat Local Blockchain Setup Script
# Run with:  chmod +x setup_hardhat.sh && ./setup_hardhat.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e  # exit on any error

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

# ─────────────────────────────────────────────────────────────────────────────
step "Step 1 — Checking Node.js"
# ─────────────────────────────────────────────────────────────────────────────

if command -v node &>/dev/null; then
  NODE_VER=$(node --version)
  NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v\([0-9]*\).*/\1/')
  if [ "$NODE_MAJOR" -ge 18 ]; then
    success "Node.js $NODE_VER found — requirement met"
  else
    warn "Node.js $NODE_VER is too old (need v18+). Installing Node 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
    success "Node.js $(node --version) installed"
  fi
else
  warn "Node.js not found. Installing Node 20 via NodeSource..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt install -y nodejs
  success "Node.js $(node --version) installed"
fi

info "npm version: $(npm --version)"

# ─────────────────────────────────────────────────────────────────────────────
step "Step 2 — Creating project folder"
# ─────────────────────────────────────────────────────────────────────────────

HARDHAT_DIR="$HOME/hardhat-ev2ev"

if [ -d "$HARDHAT_DIR" ]; then
  warn "Folder $HARDHAT_DIR already exists — skipping creation"
else
  mkdir -p "$HARDHAT_DIR"
  success "Created $HARDHAT_DIR"
fi

cd "$HARDHAT_DIR"
info "Working in: $(pwd)"

# ─────────────────────────────────────────────────────────────────────────────
step "Step 3 — Installing Hardhat"
# ─────────────────────────────────────────────────────────────────────────────

if [ ! -f "package.json" ]; then
  npm init -y
  npm pkg set type="module"
  success "npm project initialised (ESM mode)"
else
  warn "package.json exists — skipping npm init"
fi

if [ ! -d "node_modules/hardhat" ]; then
  info "Installing Hardhat (this may take 30-60 seconds)..."
  npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
  success "Hardhat installed"
else
  warn "Hardhat already installed — skipping"
fi

# ─────────────────────────────────────────────────────────────────────────────
step "Step 4 — Setting up project structure"
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p contracts scripts

# Write hardhat.config.js
cat > hardhat.config.js << 'HCONFIG'
import "@nomicfoundation/hardhat-toolbox/register.js";

export default {
  solidity: "0.8.20",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
  },
};
HCONFIG
success "hardhat.config.js written"

# Write deploy script
cat > scripts/deploy.js << 'DEPLOY'
import hre from "hardhat";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("\n Deploying with account:", deployer.address);
  const balance = await deployer.provider.getBalance(deployer.address);
  console.log(" Balance:", hre.ethers.formatEther(balance), "ETH\n");

  const EnergyEscrow = await hre.ethers.getContractFactory("EnergyEscrow");
  const escrow = await EnergyEscrow.deploy();
  await escrow.waitForDeployment();
  const address = await escrow.getAddress();

  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log(" EnergyEscrow deployed to:", address);
  console.log(" Copy this into WalletService.contractAddress");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
  fs.writeFileSync(path.join(__dirname, "..", ".last_deploy_address"), address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
DEPLOY
success "scripts/deploy.js written"

# Copy EnergyEscrow.sol if it exists in the Flutter project
FLUTTER_CONTRACT="$HOME/Desktop/PROJECT FINAL/contracts/EnergyEscrow.sol"
if [ -f "$FLUTTER_CONTRACT" ]; then
  cp "$FLUTTER_CONTRACT" contracts/
  success "EnergyEscrow.sol copied from Flutter project"
else
  warn "EnergyEscrow.sol not found at: $FLUTTER_CONTRACT"
  warn "Paste it manually into: $HARDHAT_DIR/contracts/EnergyEscrow.sol"
fi

# ─────────────────────────────────────────────────────────────────────────────
step "Step 5 — Detecting local IP address"
# ─────────────────────────────────────────────────────────────────────────────

LOCAL_IP=$(ip addr show | grep "inet 192\." | awk '{print $2}' | cut -d/ -f1 | head -1)
if [ -z "$LOCAL_IP" ]; then
  LOCAL_IP=$(hostname -I | awk '{print $1}')
fi

if [ -n "$LOCAL_IP" ]; then
  success "Your local IP: $LOCAL_IP"
  RPC_URL="http://$LOCAL_IP:8545"
else
  warn "Could not detect local IP automatically"
  RPC_URL="http://YOUR_PC_IP:8545"
fi

# ─────────────────────────────────────────────────────────────────────────────
step "Step 6 — Writing startup script"
# ─────────────────────────────────────────────────────────────────────────────

cat > "$HOME/start_hardhat.sh" << STARTSCRIPT
#!/bin/bash
# Run this every dev session to start Hardhat and deploy your contract

GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "\n\${BOLD}Starting Hardhat local blockchain...\${RESET}"
cd $HARDHAT_DIR

# Start node in background
npx hardhat node &
HARDHAT_PID=\$!
echo -e "\${BLUE}[info]\${RESET}  Hardhat node started (PID \$HARDHAT_PID)"

# Wait for node to be ready
sleep 3

# Deploy contract
echo -e "\n\${BOLD}Deploying EnergyEscrow contract...\${RESET}"
npx hardhat run scripts/deploy.js --network localhost

echo -e "\n\${GREEN}━━━ Hardhat is running ━━━\${RESET}"
echo -e "RPC URL for your phone: \${BOLD}$RPC_URL\${RESET}"
echo -e "Mnemonic (Account #0 — 10,000 ETH):"
echo -e "\${BOLD}test test test test test test test test test test test junk\${RESET}"
echo -e "\nPress Ctrl+C to stop\n"

# Keep script alive (Hardhat node runs in foreground now)
wait \$HARDHAT_PID
STARTSCRIPT

chmod +x "$HOME/start_hardhat.sh"
success "Startup script written to ~/start_hardhat.sh"

# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}${BOLD}  Setup complete!${RESET}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
echo -e "  ${BOLD}Next steps:${RESET}"
echo -e "  1. Paste EnergyEscrow.sol into ~/hardhat-ev2ev/contracts/  (if not done)"
echo -e "  2. Run ${BOLD}~/start_hardhat.sh${RESET} to start the blockchain and deploy"
echo -e "  3. In the app — Switch Accounts → Hardhat Local → enter RPC:"
echo -e "     ${BOLD}${RPC_URL}${RESET}"
echo -e "  4. Import Account #0 using this mnemonic phrase:"
echo -e "     ${BOLD}test test test test test test test test test test test junk${RESET}"
echo -e "  5. Paste the contract address printed by deploy into:"
echo -e "     ${BOLD}WalletService.contractAddress${RESET}\n"
