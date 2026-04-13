#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  EV2EV — Server Blockchain Node Setup
#  Run on a fresh Ubuntu 20.04/22.04/24.04 server (VPS, cloud, or local)
#  Safe to re-run — every step checks before acting
#  Includes: Node.js, Hardhat 2.22.2, EnergyEscrow deployment,
#            firewall config, systemd service, QR code generation
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Load nvm if available (official Node.js — avoids Ubuntu bus error) ────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# ── Colours ───────────────────────────────────────────────────────────────────
R=$'\033[0;31m'  G=$'\033[0;32m'  Y=$'\033[0;33m'  B=$'\033[0;34m'
C=$'\033[0;36m'  W=$'\033[1;37m'  D=$'\033[2m'      BOLD=$'\033[1m'
RESET=$'\033[0m'

ok()      { echo -e "  ${G}✓${RESET}  $*"; }
fail()    { echo -e "  ${R}✗${RESET}  $*"; exit 1; }
info()    { echo -e "  ${B}ℹ${RESET}  $*"; }
warn()    { echo -e "  ${Y}!${RESET}  $*"; }
skip()    { echo -e "  ${D}–  $* (already done)${RESET}"; }
ask()     { echo -e "\n  ${BOLD}${G}?${RESET}  $*"; }
divider() { echo -e "\n  ${D}────────────────────────────────────────────────────${RESET}"; }
header()  { echo -e "\n  ${BOLD}${C}▸ $*${RESET}"; divider; }

# ── Config ────────────────────────────────────────────────────────────────────
HARDHAT_DIR="$HOME/hardhat-ev2ev"
HARDHAT_PORT=8545
SERVICE_NAME="ev2ev-hardhat"
LOG_FILE="$HOME/ev2ev-hardhat.log"
PID_FILE="/tmp/ev2ev-hardhat.pid"
FLUTTER_WALLET_SERVICE=""   # auto-detected or set manually

# ── Hardhat accounts (pre-funded, publicly known) ─────────────────────────────
declare -A HH_ACCOUNTS=(
  [0]="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  [1]="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
  [2]="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
  [3]="0x90F79bf6EB2c4f870365E785982E1f101E93b906"
  [4]="0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
  [5]="0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
  [6]="0x976EA74026E726554dB657fA54763abd0C3a0aa9"
  [7]="0x14dC79964da2C08b23698B3D3cc7Ca32193d9955"
  [8]="0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f"
  [9]="0xa0Ee7A142d267C1f36714E4a8F75612F20a79720"
)
declare -A HH_KEYS=(
  [0]="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  [1]="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
  [2]="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
  [3]="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
  [4]="0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"
  [5]="0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba"
  [6]="0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e"
  [7]="0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356"
  [8]="0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97"
  [9]="0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6"
)
MNEMONIC="test test test test test test test test test test test junk"

# ═══════════════════════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════════════════════
clear
echo ""
echo -e "${BOLD}${G}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║      EV2EV — Blockchain Server Setup                ║"
echo "  ║  Hardhat 2.22.2  •  EnergyEscrow  •  Firewall      ║"
echo "  ║  Safe to re-run  •  idempotent  •  interactive      ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "  ${D}Running on: $(uname -n)  |  $(lsb_release -ds 2>/dev/null || uname -s)${RESET}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1 — SYSTEM PACKAGES
# ═══════════════════════════════════════════════════════════════════════════════
header "Step 1 — System Packages"

# curl
if command -v curl &>/dev/null; then
  skip "curl $(curl --version | head -1 | awk '{print $2}')"
else
  info "Installing curl..."
  sudo apt-get update -q && sudo apt-get install -y curl
  ok "curl installed"
fi

# python3 + qrcode
if python3 -c "import qrcode" 2>/dev/null; then
  skip "python3 qrcode library"
else
  info "Installing python3-pip and qrcode..."
  sudo apt-get install -y python3-pip 2>/dev/null || true
  pip3 install qrcode --break-system-packages 2>/dev/null || \
    pip3 install --user qrcode 2>/dev/null || \
    pip3 install qrcode 2>/dev/null || true
  python3 -c "import qrcode" 2>/dev/null && ok "qrcode installed" || warn "qrcode unavailable — QR will be text only"
fi

# lsof (for port checks)
if ! command -v lsof &>/dev/null; then
  sudo apt-get install -y lsof 2>/dev/null || true
fi

# ufw (firewall)
if ! command -v ufw &>/dev/null; then
  info "Installing ufw..."
  sudo apt-get install -y ufw
  ok "ufw installed"
else
  skip "ufw $(ufw --version 2>/dev/null | head -1)"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2 — NODE.JS
# ═══════════════════════════════════════════════════════════════════════════════
header "Step 2 — Node.js"

NODE_OK=false
if command -v node &>/dev/null; then
  NODE_VER=$(node --version)
  NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v\([0-9]*\).*/\1/')
  NODE_PATH=$(command -v node)
  if [ "$NODE_MAJOR" -ge 18 ] && [ "$NODE_MAJOR" -le 22 ]; then
    # Warn if using Ubuntu-packaged Node (known to cause bus errors with Hardhat)
    if echo "$NODE_PATH" | grep -q '/usr/bin/node'; then
      warn "Ubuntu-packaged Node.js detected ($NODE_PATH)"
      warn "This version causes 'Bus error' with Hardhat — will install via nvm"
      NODE_OK=false
    else
      skip "Node.js $NODE_VER ($NODE_PATH)"
      NODE_OK=true
    fi
  else
    warn "Node.js $NODE_VER not in range 18-22 — will upgrade"
  fi
fi

if [ "$NODE_OK" = false ]; then
  info "Installing Node.js 20 via nvm (official binary — avoids bus error)..."

  # Install nvm if not present
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    info "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
  else
    skip "nvm already installed"
    source "$NVM_DIR/nvm.sh"
  fi

  # Install Node 20 via nvm
  if ! nvm ls 20 2>/dev/null | grep -q 'v20'; then
    info "Installing Node.js 20..."
    nvm install 20
  else
    skip "Node.js 20 already installed via nvm"
  fi
  nvm use 20
  nvm alias default 20

  # Fallback: apt if nvm fails
  if ! command -v node &>/dev/null; then
    warn "nvm failed — falling back to apt"
    sudo apt-get install -y nodejs npm 2>/dev/null || true
  fi

  # npm may be missing even after nodejs install (apt quirk)
  if ! command -v npm &>/dev/null; then
    info "npm not found — installing separately..."
    sudo apt-get install -y npm 2>/dev/null || \
      curl -fsSL https://www.npmjs.com/install.sh | sudo bash 2>/dev/null || true
  fi

  # If npm still missing, install via node's bundled npm
  if ! command -v npm &>/dev/null; then
    NODE_BIN=$(dirname "$(command -v node)")
    if [ -f "$NODE_BIN/npm" ]; then
      sudo ln -sf "$NODE_BIN/npm" /usr/local/bin/npm
    fi
  fi

  NODE_VER=$(node --version 2>/dev/null || echo 'unknown')
  NPM_VER=$(npm --version 2>/dev/null || echo 'missing')
  ok "Node.js $NODE_VER installed"
  [ "$NPM_VER" != "missing" ] && ok "npm $NPM_VER" || fail "npm not found — install manually: sudo apt install npm"
fi

# Final npm check — try several locations before giving up
if ! command -v npm &>/dev/null; then
  # Refresh PATH — apt may have installed it to a location not yet in PATH
  export PATH="/usr/bin:/usr/local/bin:$PATH"
  hash -r 2>/dev/null || true
fi

if ! command -v npm &>/dev/null; then
  # Try common explicit paths
  for NPM_PATH in /usr/bin/npm /usr/local/bin/npm /usr/share/npm/bin/npm; do
    if [ -x "$NPM_PATH" ]; then
      sudo ln -sf "$NPM_PATH" /usr/local/bin/npm 2>/dev/null || true
      export PATH="/usr/local/bin:$PATH"
      break
    fi
  done
fi

if ! command -v npm &>/dev/null; then
  # Last resort — install now
  info "npm still not found — installing now..."
  sudo apt-get install -y npm 2>/dev/null
  export PATH="/usr/bin:/usr/local/bin:$PATH"
  hash -r 2>/dev/null || true
fi

if ! command -v npm &>/dev/null; then
  fail "npm is not available. Run: sudo apt install npm  then re-run this script."
fi

ok "npm $(npm --version) ready"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3 — HARDHAT PROJECT
# ═══════════════════════════════════════════════════════════════════════════════
header "Step 3 — Hardhat 2.22.2 Project"

mkdir -p "$HARDHAT_DIR/contracts" "$HARDHAT_DIR/scripts"
cd "$HARDHAT_DIR"

# package.json
if [ ! -f "package.json" ]; then
  npm init -y > /dev/null
  ok "package.json created"
else
  skip "package.json"
fi

# Force CommonJS — critical for Hardhat 2
CURRENT_TYPE=$(node -e "try{console.log(require('./package.json').type||'none')}catch(e){console.log('none')}" 2>/dev/null)
if [ "$CURRENT_TYPE" = "module" ] || [ "$CURRENT_TYPE" = "none" ]; then
  npm pkg set type="commonjs" > /dev/null 2>&1
  ok "CommonJS mode set"
else
  skip "CommonJS mode"
fi

# Check Hardhat version — must be exactly 2.22.2
INSTALLED_HH=$(node -e "try{console.log(require('./node_modules/hardhat/package.json').version)}catch(e){console.log('none')}" 2>/dev/null)
if [ "$INSTALLED_HH" = "2.22.2" ]; then
  skip "Hardhat 2.22.2"
else
  if [ "$INSTALLED_HH" != "none" ]; then
    info "Removing incompatible Hardhat $INSTALLED_HH..."
    npm remove hardhat @nomicfoundation/hardhat-toolbox @nomicfoundation/hardhat-ethers 2>/dev/null || true
  fi
  info "Installing Hardhat 2.22.2 + hardhat-ethers 3.0.8 + ethers 6.13.0..."
  info "(This may take several minutes on slow connections)"

  # Configure npm for slow/unstable networks
  npm config set fetch-retry-mintimeout 20000  2>/dev/null || true
  npm config set fetch-retry-maxtimeout 120000 2>/dev/null || true
  npm config set fetch-retries 5               2>/dev/null || true
  npm config set fetch-timeout 300000          2>/dev/null || true

  # Install packages one at a time — avoids one large failing request
  INSTALL_OK=false
  for ATTEMPT in 1 2 3; do
    info "Attempt $ATTEMPT of 3..."
    if npm install --save-dev hardhat@2.22.2 --legacy-peer-deps 2>/dev/null && \
       npm install --save-dev "@nomicfoundation/hardhat-ethers@3.0.8" --legacy-peer-deps 2>/dev/null && \
       npm install --save-dev "ethers@6.13.0" --legacy-peer-deps 2>/dev/null; then
      INSTALL_OK=true
      break
    fi
    warn "Attempt $ATTEMPT failed — waiting 10s before retry..."
    sleep 10
  done

  if [ "$INSTALL_OK" = false ]; then
    # Last resort: try all three together with --prefer-offline
    warn "Individual installs failed — trying combined with cache..."
    npm install --save-dev \
      hardhat@2.22.2 \
      "@nomicfoundation/hardhat-ethers@3.0.8" \
      "ethers@6.13.0" \
      --legacy-peer-deps --prefer-offline 2>/dev/null || \
    npm install --save-dev \
      hardhat@2.22.2 \
      "@nomicfoundation/hardhat-ethers@3.0.8" \
      "ethers@6.13.0" \
      --legacy-peer-deps || \
    fail "npm install failed after 3 attempts. Check your internet connection and re-run."
  fi

  ok "Hardhat 2.22.2 installed"
fi

# ── hardhat.config.js (always rewritten — idempotent) ─────────────────────────
cat > hardhat.config.js << 'CONFIG'
require("@nomicfoundation/hardhat-ethers");

module.exports = {
  solidity: "0.8.20",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
      gas: 12000000,
      gasPrice: 8000000000,
    },
    hardhat: {
      gas: 12000000,
      gasPrice: 8000000000,
      blockGasLimit: 12000000,
      // Bind to all interfaces so remote phones/devices can connect
      hostname: "0.0.0.0",
    },
  },
};
CONFIG
ok "hardhat.config.js written (hostname: 0.0.0.0)"

# ── deploy.js — fixed BigInt conversion, no EIP-155 issues ────────────────────
cat > scripts/deploy.js << 'DEPLOY'
const hre = require("hardhat");
const fs  = require("fs");
const path = require("path");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const balance = await deployer.provider.getBalance(deployer.address);
  console.log("DEPLOYER:" + deployer.address);
  console.log("BALANCE:" + hre.ethers.formatEther(balance));

  const Factory = await hre.ethers.getContractFactory("EnergyEscrow");
  const contract = await Factory.deploy();
  await contract.waitForDeployment();
  const address = await contract.getAddress();

  console.log("CONTRACT_ADDRESS:" + address);
  fs.writeFileSync(
    path.join(__dirname, "..", ".last_deploy_address"),
    address
  );
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
DEPLOY
ok "scripts/deploy.js written"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4 — EnergyEscrow.sol
# ═══════════════════════════════════════════════════════════════════════════════
header "Step 4 — EnergyEscrow.sol"

SOL_DEST="$HARDHAT_DIR/contracts/EnergyEscrow.sol"
SOL_FOUND=false

if [ -f "$SOL_DEST" ]; then
  skip "EnergyEscrow.sol already in contracts/"
  SOL_FOUND=true
else
  # Search common locations
  for SOL_PATH in \
    "$HOME/Desktop/PROJECT FINAL/contracts/EnergyEscrow.sol" \
    "$HOME/Desktop/PROJECT FINAL/BLOCKCHAIN_NETWORK/EnergyEscrow.sol" \
    "$HOME/Desktop/PROJECT FINAL/EnergyEscrow.sol" \
    "$(dirname "$0")/EnergyEscrow.sol" \
    "$HOME/EnergyEscrow.sol"; do
    if [ -f "$SOL_PATH" ]; then
      cp "$SOL_PATH" "$SOL_DEST"
      ok "EnergyEscrow.sol found and copied from $SOL_PATH"
      SOL_FOUND=true
      break
    fi
  done
fi

if [ "$SOL_FOUND" = false ]; then
  warn "EnergyEscrow.sol not found automatically."
  echo ""
  echo -e "  Options:"
  echo -e "  ${BOLD}1${RESET}  Enter path to existing EnergyEscrow.sol"
  echo -e "  ${BOLD}2${RESET}  Generate a minimal EnergyEscrow.sol now"
  ask "Choose (1 or 2):"
  read -r SOL_CHOICE

  if [ "$SOL_CHOICE" = "1" ]; then
    ask "Full path to EnergyEscrow.sol:"
    read -r SOL_INPUT
    if [ -f "$SOL_INPUT" ]; then
      cp "$SOL_INPUT" "$SOL_DEST"
      ok "EnergyEscrow.sol copied"
      SOL_FOUND=true
    else
      fail "File not found: $SOL_INPUT"
    fi
  else
    info "Generating EnergyEscrow.sol..."
    cat > "$SOL_DEST" << 'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EnergyEscrow {
    enum TradeStatus { None, Active, Delivered, Complete, Disputed, Refunded }

    struct Trade {
        address payable buyer;
        address payable seller;
        uint256 amount;
        uint256 energyMilliKwh;
        uint256 pricePerKwh;
        string  requestId;
        TradeStatus status;
        uint256 createdAt;
        uint256 deliveredAt;
    }

    mapping(bytes32 => Trade) public trades;

    uint256 public constant FEE_BPS     = 150;  // 1.5%
    uint256 public constant DISPUTE_WIN = 24 hours;
    uint256 public constant REFUND_WIN  = 48 hours;

    address public owner;

    event TradeCreated(bytes32 indexed tradeId, address buyer, address seller, uint256 amount);
    event Delivered(bytes32 indexed tradeId);
    event Completed(bytes32 indexed tradeId, uint256 sellerAmount, uint256 fee);
    event Disputed(bytes32 indexed tradeId);
    event Refunded(bytes32 indexed tradeId);

    constructor() { owner = msg.sender; }

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }

    function deposit(
        address payable seller,
        uint256 energyMilliKwh,
        uint256 pricePerKwh,
        string calldata requestId
    ) external payable returns (bytes32 tradeId) {
        require(msg.value > 0, "No ETH sent");
        require(seller != address(0), "Bad seller");
        tradeId = keccak256(abi.encodePacked(msg.sender, seller, block.timestamp, requestId));
        require(trades[tradeId].buyer == address(0), "Trade exists");
        trades[tradeId] = Trade({
            buyer:           payable(msg.sender),
            seller:          seller,
            amount:          msg.value,
            energyMilliKwh:  energyMilliKwh,
            pricePerKwh:     pricePerKwh,
            requestId:       requestId,
            status:          TradeStatus.Active,
            createdAt:       block.timestamp,
            deliveredAt:     0
        });
        emit TradeCreated(tradeId, msg.sender, seller, msg.value);
    }

    function confirmDelivery(bytes32 tradeId) external {
        Trade storage t = trades[tradeId];
        require(msg.sender == t.seller, "Not seller");
        require(t.status == TradeStatus.Active, "Not active");
        t.status      = TradeStatus.Delivered;
        t.deliveredAt = block.timestamp;
        emit Delivered(tradeId);
    }

    function confirmReceipt(bytes32 tradeId) external {
        Trade storage t = trades[tradeId];
        require(msg.sender == t.buyer, "Not buyer");
        require(t.status == TradeStatus.Delivered, "Not delivered");
        t.status = TradeStatus.Complete;
        uint256 fee    = (t.amount * FEE_BPS) / 10000;
        uint256 payout = t.amount - fee;
        t.seller.transfer(payout);
        payable(owner).transfer(fee);
        emit Completed(tradeId, payout, fee);
    }

    function raiseDispute(bytes32 tradeId) external {
        Trade storage t = trades[tradeId];
        require(msg.sender == t.buyer, "Not buyer");
        require(t.status == TradeStatus.Delivered, "Not delivered");
        require(block.timestamp <= t.deliveredAt + DISPUTE_WIN, "Window passed");
        t.status = TradeStatus.Disputed;
        emit Disputed(tradeId);
    }

    function resolveDispute(bytes32 tradeId, bool favourSeller) external onlyOwner {
        Trade storage t = trades[tradeId];
        require(t.status == TradeStatus.Disputed, "Not disputed");
        t.status = TradeStatus.Complete;
        if (favourSeller) {
            uint256 fee = (t.amount * FEE_BPS) / 10000;
            t.seller.transfer(t.amount - fee);
            payable(owner).transfer(fee);
        } else {
            t.buyer.transfer(t.amount);
        }
    }

    function refund(bytes32 tradeId) external {
        Trade storage t = trades[tradeId];
        require(msg.sender == t.buyer, "Not buyer");
        require(t.status == TradeStatus.Active, "Not active");
        require(block.timestamp >= t.createdAt + REFUND_WIN, "Too early");
        t.status = TradeStatus.Refunded;
        t.buyer.transfer(t.amount);
        emit Refunded(tradeId);
    }

    function getTradeStatus(bytes32 tradeId) external view returns (TradeStatus) {
        return trades[tradeId].status;
    }

    function getTrade(bytes32 tradeId) external view returns (Trade memory) {
        return trades[tradeId];
    }
}
SOL
    ok "EnergyEscrow.sol generated"
    SOL_FOUND=true
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5 — IP / SERVER ADDRESS DETECTION
# ═══════════════════════════════════════════════════════════════════════════════
header "Step 5 — Server IP Detection"

# Collect all candidate IPs
ALL_IPS=()
while IFS= read -r ip; do
  ALL_IPS+=("$ip")
done < <(ip addr show 2>/dev/null | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+' | grep -v '^127\.' | grep -v '^169\.' || true)

# Also try hostname
HOSTNAME_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

# Try to detect public/cloud IP (works on AWS, GCP, DO, Hetzner, etc.)
PUBLIC_IP=""
PUBLIC_IP=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || \
            curl -s --max-time 3 https://ifconfig.me 2>/dev/null || \
            curl -s --max-time 3 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)

echo ""
if [ -n "$PUBLIC_IP" ]; then
  echo -e "  ${G}Detected public IP: $PUBLIC_IP${RESET}"
fi
if [ ${#ALL_IPS[@]} -gt 0 ]; then
  echo -e "  ${B}Local interfaces:${RESET}"
  for i in "${!ALL_IPS[@]}"; do
    echo -e "    ${BOLD}[$((i+1))]${RESET} ${ALL_IPS[$i]}"
  done
fi

echo ""
echo -e "  ${BOLD}What IP/hostname should the app connect to?${RESET}"
echo -e "  ${D}Use public IP for VPS/cloud, local IP for LAN, or a domain name.${RESET}"
echo ""
if [ -n "$PUBLIC_IP" ]; then
  echo -e "  ${BOLD}P${RESET}  Use public IP: $PUBLIC_IP"
fi
for i in "${!ALL_IPS[@]}"; do
  echo -e "  ${BOLD}$((i+1))${RESET}  Use local IP: ${ALL_IPS[$i]}"
done
echo -e "  ${BOLD}C${RESET}  Enter custom IP or hostname"

ask "Choose:"
read -r IP_CHOICE

case "${IP_CHOICE^^}" in
  P) SERVER_IP="$PUBLIC_IP" ;;
  C)
    ask "Enter IP address or hostname:"
    read -r SERVER_IP
    ;;
  *)
    if [[ "$IP_CHOICE" =~ ^[0-9]+$ ]] && [ "$IP_CHOICE" -ge 1 ] && [ "$IP_CHOICE" -le "${#ALL_IPS[@]}" ]; then
      SERVER_IP="${ALL_IPS[$((IP_CHOICE-1))]}"
    else
      SERVER_IP="${IP_CHOICE}"
    fi
    ;;
esac

[ -z "$SERVER_IP" ] && { ask "Enter server IP:"; read -r SERVER_IP; }

# ── WSL2 detection: node listens on WSL2 IP, but phone connects via Windows IP ──
QR_IP="$SERVER_IP"
if echo "$SERVER_IP" | grep -qE '^172\.(1[6-9]|2[0-9]|3[01])\.' || \
   echo "$SERVER_IP" | grep -qE '^10\.255\.'; then
  echo ""
  warn "WSL2 IP detected ($SERVER_IP)."
  warn "The phone cannot reach WSL2 directly — it must connect via your Windows IP."
  echo ""
  # Try to auto-detect Windows host IP
  WIN_IP=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}' | head -1)
  # Also check default route
  ROUTE_IP=$(ip route | grep default | awk '{print $3}' | head -1)
  echo -e "  ${BOLD}Which IP should the phone/app use to connect?${RESET}"
  [ -n "$WIN_IP" ]   && echo -e "  ${BOLD}W${RESET}  Windows host IP (from resolv.conf): $WIN_IP"
  [ -n "$ROUTE_IP" ] && echo -e "  ${BOLD}R${RESET}  Default route IP: $ROUTE_IP"
  echo -e "  ${BOLD}C${RESET}  Enter manually (e.g. your Windows WiFi IP like 192.168.x.x)"
  ask "Choose:"
  read -r QR_CHOICE
  case "${QR_CHOICE^^}" in
    W) QR_IP="$WIN_IP" ;;
    R) QR_IP="$ROUTE_IP" ;;
    *)
      if echo "$QR_CHOICE" | grep -qP '^\d+\.\d+\.\d+\.\d+$'; then
        QR_IP="$QR_CHOICE"
      else
        ask "Enter the Windows/router-facing IP the phone will connect to:"
        read -r QR_IP
      fi
      ;;
  esac
  echo ""
  info "Node will listen on : $SERVER_IP:$HARDHAT_PORT (WSL2)"
  info "Phone will connect to: $QR_IP:$HARDHAT_PORT (Windows port proxy)"
  warn "Make sure Windows port proxy is set: netsh interface portproxy add v4tov4"
  warn "  listenport=8545 listenaddress=0.0.0.0 connectport=8545 connectaddress=$SERVER_IP"
fi

RPC_URL="http://$QR_IP:$HARDHAT_PORT"
ok "Node listens on : http://$SERVER_IP:$HARDHAT_PORT"
ok "App connects to : $RPC_URL"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6 — FIREWALL
# ═══════════════════════════════════════════════════════════════════════════════
header "Step 6 — Firewall & Port $HARDHAT_PORT"

echo ""
echo -e "  ${BOLD}Firewall options:${RESET}"
echo -e "  ${BOLD}1${RESET}  Open port $HARDHAT_PORT to all (any IP — simplest for LAN/dev)"
echo -e "  ${BOLD}2${RESET}  Open port $HARDHAT_PORT to specific IP only (more secure)"
echo -e "  ${BOLD}3${RESET}  Skip firewall changes (already configured / no sudo)"
echo ""
ask "Choose:"
read -r FW_CHOICE

case "$FW_CHOICE" in
  1)
    # Enable ufw + open SSH first (safety) + open 8545
    if sudo ufw status | grep -q "Status: inactive"; then
      info "Enabling ufw (allowing SSH first to avoid lockout)..."
      sudo ufw allow ssh 2>/dev/null || sudo ufw allow 22/tcp
    fi
    sudo ufw allow "$HARDHAT_PORT/tcp" comment "EV2EV Hardhat node" 2>/dev/null || true
    sudo ufw --force enable 2>/dev/null || true
    ok "Port $HARDHAT_PORT open to all"
    ;;
  2)
    ask "Enter allowed IP address (e.g. your phone/office IP):"
    read -r ALLOWED_IP
    if sudo ufw status | grep -q "Status: inactive"; then
      sudo ufw allow ssh 2>/dev/null || sudo ufw allow 22/tcp
    fi
    sudo ufw allow from "$ALLOWED_IP" to any port "$HARDHAT_PORT" proto tcp \
      comment "EV2EV Hardhat - $ALLOWED_IP" 2>/dev/null || true
    sudo ufw --force enable 2>/dev/null || true
    ok "Port $HARDHAT_PORT open to $ALLOWED_IP only"
    ;;
  3)
    warn "Skipping firewall. Ensure port $HARDHAT_PORT is accessible externally."
    ;;
esac

# Also handle cloud provider security groups (reminder)
echo ""
if [ -n "$PUBLIC_IP" ]; then
  warn "If running on AWS/GCP/Azure/DigitalOcean, also open port $HARDHAT_PORT"
  warn "in your cloud provider's Security Group / Firewall rules."
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7 — NODE STARTUP MODE
# ═══════════════════════════════════════════════════════════════════════════════
header "Step 7 — Node Startup Mode"

echo ""
echo -e "  ${BOLD}How should the Hardhat node run?${RESET}"
echo -e "  ${BOLD}1${RESET}  Foreground — runs in this terminal (stops when terminal closes)"
echo -e "  ${BOLD}2${RESET}  Background — nohup process (survives terminal close)"
echo -e "  ${BOLD}3${RESET}  systemd service — starts on boot, auto-restart (recommended for servers)"
echo ""
ask "Choose:"
read -r MODE

case "$MODE" in
  3)
    RUN_MODE="systemd"
    ;;
  2)
    RUN_MODE="background"
    ;;
  *)
    RUN_MODE="foreground"
    ;;
esac

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 8 — STOP EXISTING NODE
# ═══════════════════════════════════════════════════════════════════════════════
header "Step 8 — Check Existing Node on Port $HARDHAT_PORT"

NODE_WAS_RUNNING=false
if lsof -ti:"$HARDHAT_PORT" &>/dev/null 2>&1 || \
   curl -s -X POST "http://127.0.0.1:$HARDHAT_PORT" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
     --max-time 2 2>/dev/null | grep -q "result"; then
  NODE_WAS_RUNNING=true
  warn "Hardhat node already running on port $HARDHAT_PORT"
  ask "Stop it and start fresh chain? (y/N):"
  read -r RESTART_CHOICE
  if [[ "$RESTART_CHOICE" =~ ^[Yy] ]]; then
    PID=$(lsof -ti:"$HARDHAT_PORT" 2>/dev/null | head -1)
    [ -n "$PID" ] && kill "$PID" 2>/dev/null && sleep 2
    # Also stop systemd service if running
    sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    ok "Existing node stopped"
    NODE_WAS_RUNNING=false
  else
    info "Keeping existing node — will deploy contract to it"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 9 — START NODE
# ═══════════════════════════════════════════════════════════════════════════════
header "Step 9 — Starting Hardhat Node"

NODE_STARTED=false

if [ "$NODE_WAS_RUNNING" = false ]; then
  cd "$HARDHAT_DIR"

  if [ "$RUN_MODE" = "systemd" ]; then
    NODE_EXEC="$(command -v npx 2>/dev/null || echo /usr/bin/npx)"
    HARDHAT_EXEC="$NODE_EXEC hardhat node --hostname 0.0.0.0"

    sudo tee /etc/systemd/system/"$SERVICE_NAME".service > /dev/null << SVCEOF
[Unit]
Description=EV2EV Hardhat Local Blockchain Node
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HARDHAT_DIR
ExecStart=$HARDHAT_EXEC
Restart=always
RestartSec=5
StandardOutput=append:/var/log/ev2ev-hardhat.log
StandardError=append:/var/log/ev2ev-hardhat.log
Environment=HOME=$HOME

[Install]
WantedBy=multi-user.target
SVCEOF

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME" 2>/dev/null
    sudo systemctl restart "$SERVICE_NAME"
    info "Waiting for systemd service to start..."
    sleep 4
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
      ok "systemd service '$SERVICE_NAME' running (auto-starts on boot)"
      NODE_STARTED=true
    else
      fail "Service failed to start. Check: sudo journalctl -u $SERVICE_NAME -n 30"
    fi

  elif [ "$RUN_MODE" = "background" ]; then
    info "Starting Hardhat node in background..."
    # Ensure log file is writable
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/ev2ev-hardhat.log"
    # Resolve full path to npx — nohup may not inherit PATH
    NPX_BIN=$(command -v npx 2>/dev/null || echo "$(npm bin)/npx" 2>/dev/null || echo "/usr/bin/npx")
    info "Using npx at: $NPX_BIN"
    cd "$HARDHAT_DIR"
    nohup "$NPX_BIN" hardhat node --hostname 0.0.0.0 \
      > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    info "Waiting for node to be ready..."
    echo -n "  "
    for i in $(seq 1 20); do
      if curl -s -X POST "http://127.0.0.1:$HARDHAT_PORT" \
           -H "Content-Type: application/json" \
           -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
           --max-time 1 2>/dev/null | grep -q "result"; then
        echo ""
        ok "Node running in background (PID $(cat "$PID_FILE"))"
        NODE_STARTED=true
        break
      fi
      echo -n "."
      sleep 1
      if [ "$i" -eq 20 ]; then
        echo ""
        fail "Node failed to start after 20s. Check log: ${LOG_FILE:-/tmp/ev2ev-hardhat.log}"
      fi
    done

  else
    # Foreground — start in background temporarily so we can deploy, then offer to foreground
    info "Starting node (temporarily background for deployment)..."
    touch /tmp/ev2ev-hardhat-tmp.log 2>/dev/null || true
    NPX_BIN=$(command -v npx 2>/dev/null || echo "/usr/bin/npx")
    cd "$HARDHAT_DIR"
    nohup "$NPX_BIN" hardhat node --hostname 0.0.0.0 > /tmp/ev2ev-hardhat-tmp.log 2>&1 &
    TMP_PID=$!
    echo -n "  "
    for i in $(seq 1 20); do
      if curl -s -X POST "http://127.0.0.1:$HARDHAT_PORT" \
           -H "Content-Type: application/json" \
           -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
           --max-time 1 2>/dev/null | grep -q "result"; then
        echo ""
        ok "Node ready (PID $TMP_PID)"
        NODE_STARTED=true
        break
      fi
      echo -n "."
      sleep 1
    done
  fi
fi

# Confirm node is reachable
if curl -s -X POST "http://127.0.0.1:$HARDHAT_PORT" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
     --max-time 3 2>/dev/null | grep -q "result"; then
  CHAIN=$(curl -s -X POST "http://127.0.0.1:$HARDHAT_PORT" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    --max-time 3 | python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['result'],16))" 2>/dev/null)
  ok "Node reachable — chain ID: $CHAIN"
else
  fail "Node not responding on port $HARDHAT_PORT"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 10 — DEPLOY CONTRACT
# ═══════════════════════════════════════════════════════════════════════════════
header "Step 10 — Deploy EnergyEscrow Contract"

REDEPLOY=true
if [ -f "$HARDHAT_DIR/.last_deploy_address" ]; then
  EXISTING=$(cat "$HARDHAT_DIR/.last_deploy_address")
  # Verify bytecode still exists at that address
  CODE=$(curl -s -X POST "http://127.0.0.1:$HARDHAT_PORT" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$EXISTING\",\"latest\"],\"id\":1}" \
    --max-time 3 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result','0x'))" 2>/dev/null)

  if [ "$CODE" != "0x" ] && [ -n "$CODE" ] && [ ${#CODE} -gt 4 ]; then
    skip "Contract already deployed at $EXISTING"
    ask "Redeploy fresh contract? (y/N):"
    read -r RD
    [[ "$RD" =~ ^[Yy] ]] && REDEPLOY=true || { REDEPLOY=false; CONTRACT_ADDRESS="$EXISTING"; }
  fi
fi

if [ "$REDEPLOY" = true ]; then
  info "Compiling and deploying EnergyEscrow..."
  cd "$HARDHAT_DIR"
  DEPLOY_OUT=$(npx hardhat run scripts/deploy.js --network localhost 2>&1 | \
    grep -v 'WARNING:' | grep -v '^$' | sed 's/\x1b\[[0-9;]*m//g')

  # Parse address — accepts both output formats
  CONTRACT_ADDRESS=$(echo "$DEPLOY_OUT" | grep -oP '0x[0-9a-fA-F]{40}' | tail -1)

  # Fallback to file
  if [ -z "$CONTRACT_ADDRESS" ] && [ -f "$HARDHAT_DIR/.last_deploy_address" ]; then
    CONTRACT_ADDRESS=$(cat "$HARDHAT_DIR/.last_deploy_address")
  fi

  [ -z "$CONTRACT_ADDRESS" ] && { echo "$DEPLOY_OUT"; fail "Deployment failed — no address found"; }

  echo "$CONTRACT_ADDRESS" > "$HARDHAT_DIR/.last_deploy_address"
  ok "Contract deployed: $CONTRACT_ADDRESS"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 11 — PATCH FLUTTER APP (if found)
# ═══════════════════════════════════════════════════════════════════════════════
header "Step 11 — Patch Flutter App"

# Search for wallet_service.dart
WALLET_SERVICE=""
for WS_PATH in \
  "$HOME/Desktop/PROJECT FINAL/lib/services/wallet_service.dart" \
  "$HOME/ev2ev/lib/services/wallet_service.dart" \
  "$HOME/projects/ev2ev/lib/services/wallet_service.dart"; do
  if [ -f "$WS_PATH" ]; then
    WALLET_SERVICE="$WS_PATH"
    break
  fi
done

if [ -n "$WALLET_SERVICE" ]; then
  CURRENT=$(grep "static const String contractAddress" "$WALLET_SERVICE" | \
    grep -oP "0x[a-fA-F0-9]+" | head -1)
  if [ "$CURRENT" = "$CONTRACT_ADDRESS" ]; then
    skip "wallet_service.dart already has correct address"
  else
    python3 << PYEOF
import re
with open('$WALLET_SERVICE', 'r') as f: content = f.read()
content = re.sub(
    r"static const String contractAddress = '0x[^']*';[^\n]*",
    "static const String contractAddress = '$CONTRACT_ADDRESS'; // auto-patched by ev2ev_server_setup.sh",
    content
)
with open('$WALLET_SERVICE', 'w') as f: f.write(content)
print("  patched")
PYEOF
    grep -q "$CONTRACT_ADDRESS" "$WALLET_SERVICE" && \
      ok "wallet_service.dart patched" || \
      warn "Patch failed — set contractAddress manually to: $CONTRACT_ADDRESS"
  fi
else
  warn "wallet_service.dart not found — set contractAddress manually:"
  echo -e "  ${C}static const String contractAddress = '$CONTRACT_ADDRESS';${RESET}"

  ask "Enter path to wallet_service.dart (or press Enter to skip):"
  read -r MANUAL_WS
  if [ -f "$MANUAL_WS" ]; then
    python3 << PYEOF
import re
with open('$MANUAL_WS', 'r') as f: content = f.read()
content = re.sub(
    r"static const String contractAddress = '0x[^']*';[^\n]*",
    "static const String contractAddress = '$CONTRACT_ADDRESS'; // auto-patched",
    content
)
with open('$MANUAL_WS', 'w') as f: f.write(content)
PYEOF
    ok "wallet_service.dart patched at $MANUAL_WS"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 12 — GENERATE QR CODE
# ═══════════════════════════════════════════════════════════════════════════════
header "Step 12 — QR Code & Connection Info"

QR_PAYLOAD="{\"rpc\":\"$RPC_URL\",\"chainId\":31337,\"contract\":\"$CONTRACT_ADDRESS\",\"network\":\"Hardhat Local\",\"symbol\":\"ETH\",\"mnemonic\":\"$MNEMONIC\",\"account\":\"${HH_ACCOUNTS[0]}\"}"

if python3 -c "import qrcode" 2>/dev/null; then
  echo ""
  echo -e "  ${BOLD}Scan with EV2EV app → Wallet → Switch Accounts → Hardhat → QR button:${RESET}"
  echo ""
  python3 << PYEOF
import qrcode
payload = """$QR_PAYLOAD"""
qr = qrcode.QRCode(
    version=None,
    error_correction=qrcode.constants.ERROR_CORRECT_L,
    box_size=1,
    border=1,
)
qr.add_data(payload.strip())
qr.make(fit=True)
qr.print_ascii(invert=True)
PYEOF
else
  warn "qrcode library not available — QR skipped"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 13 — SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${G}  ╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${G}  ║              SETUP COMPLETE                              ║${RESET}"
echo -e "${BOLD}${G}  ╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${BOLD}Network       :${RESET} Hardhat Local"
echo -e "  ${BOLD}Chain ID      :${RESET} 31337"
echo -e "  ${BOLD}RPC URL       :${RESET} ${C}$RPC_URL${RESET}"
echo -e "  ${BOLD}Contract      :${RESET} ${C}$CONTRACT_ADDRESS${RESET}"
echo ""
echo -e "  ${BOLD}Accounts (all pre-funded with 10,000 ETH):${RESET}"
echo -e "  ${BOLD}#0${RESET}  ${D}${HH_ACCOUNTS[0]}${RESET}"
echo -e "      Mnemonic: ${G}$MNEMONIC${RESET}"
echo -e "      Key     : ${C}${HH_KEYS[0]}${RESET}"
echo ""
echo -e "  ${BOLD}#1-#9${RESET}  Import via Private Key tab in app"
echo -e "  ${BOLD}#1${RESET}  ${D}${HH_ACCOUNTS[1]}${RESET}"
echo -e "      Key: ${C}${HH_KEYS[1]}${RESET}"
echo ""

if [ "$RUN_MODE" = "systemd" ]; then
  echo -e "  ${BOLD}Service       :${RESET} systemd unit '$SERVICE_NAME'"
  echo -e "  ${BOLD}Auto-start    :${RESET} enabled (survives reboots)"
  echo -e "  ${BOLD}Logs          :${RESET} sudo journalctl -u $SERVICE_NAME -f"
  echo -e "  ${BOLD}Stop          :${RESET} sudo systemctl stop $SERVICE_NAME"
  echo -e "  ${BOLD}Restart       :${RESET} sudo systemctl restart $SERVICE_NAME"
elif [ "$RUN_MODE" = "background" ]; then
  echo -e "  ${BOLD}Node PID      :${RESET} $(cat "$PID_FILE" 2>/dev/null || echo 'see /tmp/ev2ev-hardhat.pid')"
  echo -e "  ${BOLD}Log           :${RESET} $LOG_FILE"
  echo -e "  ${BOLD}Stop          :${RESET} kill \$(cat $PID_FILE)"
fi

echo ""
echo -e "  ${Y}⚠  Chain resets when node restarts — redeploy contract after restart${RESET}"
echo -e "  ${Y}⚠  These accounts and keys are publicly known — testnet only${RESET}"
echo ""

# If foreground mode, now hand over to the node
if [ "$RUN_MODE" = "foreground" ]; then
  echo -e "  ${BOLD}Starting node in foreground (Ctrl+C to stop)...${RESET}"
  echo ""
  # Kill the temp background process
  kill "$TMP_PID" 2>/dev/null || true
  sleep 1
  cd "$HARDHAT_DIR"
  exec npx hardhat node --hostname 0.0.0.0
fi
