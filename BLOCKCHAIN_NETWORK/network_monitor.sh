#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# EV2EV — Interactive Network Monitor
# Checks node status, contract state, balances, transactions and more
# ═══════════════════════════════════════════════════════════════════════════════

# ── Colours ───────────────────────────────────────────────────────────────────
R=$'\033[0;31m' G=$'\033[0;32m' Y=$'\033[0;33m' B=$'\033[0;34m'
C=$'\033[0;36m' M=$'\033[0;35m' W=$'\033[1;37m' D=$'\033[2m'
BOLD=$'\033[1m' RESET=$'\033[0m'

# ── Config — auto-detected or from last deploy ─────────────────────────────────
HARDHAT_DIR="$HOME/hardhat-ev2ev"
RPC="http://127.0.0.1:8545"
CONTRACT_FILE="$HARDHAT_DIR/.last_deploy_address"
CONTRACT=""
CHAIN_ID=31337

# Known Hardhat accounts
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

# ── Helpers ───────────────────────────────────────────────────────────────────
ok()     { printf '  \033[0;32m✓\033[0m  %s\n' "$1"; }
fail()   { printf '  \033[0;31m✗\033[0m  %s\n' "$1"; }
info()   { printf '  \033[0;34mℹ\033[0m  %s\n' "$1"; }
warn()   { printf '  \033[0;33m!\033[0m  %s\n' "$1"; }
label()  { echo -e "  ${D}$1${RESET}"; }
ask()    { echo -e "\n  ${BOLD}${G}?${RESET}  $1"; }
header() {
  echo ""
  echo -e "${BOLD}${C}  ╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${C}  ║  $1$(printf '%*s' $((48 - ${#1})) '')║${RESET}"
  echo -e "${BOLD}${C}  ╚══════════════════════════════════════════════════╝${RESET}"
  echo ""
}
divider() { echo -e "  ${D}──────────────────────────────────────────────────${RESET}"; }
pause()  { echo ""; ask "Press Enter to continue..."; read -r; }

# ── RPC call helper ───────────────────────────────────────────────────────────
rpc() {
  local method="$1" params="${2:-[]}"
  curl -s -X POST "$RPC" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":1}" \
    --max-time 5 2>/dev/null
}

rpc_result() {
  rpc "$1" "$2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result','ERROR'))" 2>/dev/null
}

node_running() {
  rpc "eth_blockNumber" | grep -q "result"
}

wei_to_eth() {
  python3 -c "print(f'{int(\"$1\",16)/1e18:.4f}')" 2>/dev/null || echo "0"
}

load_contract() {
  # Check our own file first, then hardhat's
  if [ -f "$CONTRACT_FILE" ]; then
    CONTRACT=$(cat "$CONTRACT_FILE")
  elif [ -f "$HARDHAT_DIR/.last_deploy_address" ]; then
    CONTRACT=$(cat "$HARDHAT_DIR/.last_deploy_address")
    # Copy to our file so we find it next time
    echo "$CONTRACT" > "$CONTRACT_FILE"
  fi
}

# ── Main menu ─────────────────────────────────────────────────────────────────
main_menu() {
  while true; do
    clear
    load_contract

    # Node status indicator
    if node_running; then
      NODE_STATUS="${G}● RUNNING${RESET}"
      BLOCK=$(rpc_result "eth_blockNumber" | python3 -c "import sys; v=sys.stdin.read().strip(); print(int(v,16) if v.startswith('0x') else v)" 2>/dev/null)
    else
      NODE_STATUS="${R}● OFFLINE${RESET}"
      BLOCK="—"
    fi

    CONTRACT_SHORT="${CONTRACT:0:10}...${CONTRACT: -6}"
    [ -z "$CONTRACT" ] && CONTRACT_SHORT="${Y}not deployed${RESET}"

    echo ""
    echo -e "${BOLD}${G}  ╔═══════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${G}  ║          EV2EV Network Monitor                    ║${RESET}"
    echo -e "${BOLD}${G}  ╚═══════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  Node    : $NODE_STATUS   Block: ${W}#$BLOCK${RESET}"
    echo -e "  RPC     : ${D}$RPC${RESET}"
    echo -e "  Contract: ${D}$CONTRACT_SHORT${RESET}"
    divider
    echo ""
    echo -e "  ${BOLD}1${RESET}  Node & Network Status"
    echo -e "  ${BOLD}2${RESET}  Account Balances"
    echo -e "  ${BOLD}3${RESET}  Contract Status"
    echo -e "  ${BOLD}4${RESET}  Transaction History"
    echo -e "  ${BOLD}5${RESET}  Send ETH Between Accounts"
    echo -e "  ${BOLD}6${RESET}  Start / Stop / Restart Node"
    echo -e "  ${BOLD}7${RESET}  Deploy Contract"
    echo -e "  ${BOLD}8${RESET}  Generate QR Code"
    echo -e "  ${BOLD}9${RESET}  Settings"
    echo -e "  ${BOLD}0${RESET}  Exit"
    echo ""
    divider
    ask "Choose option:"
    read -r CHOICE

    case "$CHOICE" in
      1) menu_network ;;
      2) menu_balances ;;
      3) menu_contract ;;
      4) menu_transactions ;;
      5) menu_send ;;
      6) menu_node ;;
      7) menu_deploy ;;
      8) menu_qr ;;
      9) menu_settings ;;
      0) echo -e "\n  ${G}Goodbye!${RESET}\n"; exit 0 ;;
      *) warn "Invalid option" ; sleep 1 ;;
    esac
  done
}

# ── 1. Node & Network Status ──────────────────────────────────────────────────
menu_network() {
  clear
  header "Node & Network Status"

  if ! node_running; then
    fail "Hardhat node is NOT running on $RPC"
    warn "Start it with option 6 from the main menu"
    pause; return
  fi

  ok "Node is running at $RPC"
  echo ""

  # Block info
  BLOCK_HEX=$(rpc_result "eth_blockNumber")
  BLOCK=$( python3 -c "print(int('$BLOCK_HEX',16))" 2>/dev/null)
  info "Current block    : ${W}#$BLOCK${RESET}"

  # Chain ID
  CHAIN_HEX=$(rpc_result "eth_chainId")
  CHAIN=$(python3 -c "print(int('$CHAIN_HEX',16))" 2>/dev/null)
  info "Chain ID         : ${W}$CHAIN${RESET}"

  # Gas price
  GAS_HEX=$(rpc_result "eth_gasPrice")
  GAS=$(python3 -c "print(f'{int(\"$GAS_HEX\",16)/1e9:.1f} Gwei')" 2>/dev/null)
  info "Gas price        : ${W}$GAS${RESET}"

  # Mining status
  MINING=$(rpc_result "eth_mining")
  info "Mining           : ${W}$MINING${RESET}"

  # Peer count
  PEERS=$(rpc_result "net_peerCount" | python3 -c "import sys; v=sys.stdin.read().strip(); print(int(v,16) if v.startswith('0x') else v)" 2>/dev/null)
  info "Peers            : ${W}$PEERS${RESET} (always 0 on local)"

  # Pending txs
  PENDING=$(rpc_result "eth_getBlockTransactionCountByNumber" '["pending"]' | python3 -c "import sys; v=sys.stdin.read().strip(); print(int(v,16) if v.startswith('0x') else '0')" 2>/dev/null)
  info "Pending txs      : ${W}$PENDING${RESET}"

  # Latest block details
  echo ""
  divider
  echo -e "  ${BOLD}Latest Block${RESET}"
  divider
  BLOCK_DATA=$(rpc "eth_getBlockByNumber" '["latest",false]')
  TIMESTAMP=$(echo "$BLOCK_DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); t=d.get('result',{}).get('timestamp','0x0'); print(int(t,16))" 2>/dev/null)
  TX_COUNT=$(echo "$BLOCK_DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('result',{}).get('transactions',[])))" 2>/dev/null)
  GAS_USED=$(echo "$BLOCK_DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d.get('result',{}).get('gasUsed','0x0'),16))" 2>/dev/null)
  BLOCK_HASH=$(echo "$BLOCK_DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('hash','—')[:20]+'...')" 2>/dev/null)

  info "Block hash       : ${D}$BLOCK_HASH${RESET}"
  info "Transactions     : ${W}$TX_COUNT${RESET}"
  info "Gas used         : ${W}$GAS_USED${RESET}"
  [ -n "$TIMESTAMP" ] && info "Timestamp        : ${W}$(date -d @$TIMESTAMP 2>/dev/null || date -r $TIMESTAMP 2>/dev/null || echo $TIMESTAMP)${RESET}"

  pause
}

# ── 2. Account Balances ───────────────────────────────────────────────────────
menu_balances() {
  while true; do
    clear
    header "Account Balances"

    if ! node_running; then
      fail "Node offline — start it first (option 6)"
      pause; return
    fi

    echo -e "  ${BOLD}1${RESET}  Show all 10 Hardhat accounts"
    echo -e "  ${BOLD}2${RESET}  Check specific address"
    echo -e "  ${BOLD}3${RESET}  Watch balances (auto-refresh)"
    echo -e "  ${BOLD}4${RESET}  Show private keys & import guide"
    echo -e "  ${BOLD}0${RESET}  Back"
    echo ""
    ask "Choose:"
    read -r B

    case "$B" in
      1)
        clear
        header "Hardhat Account Balances"
        echo -e "  ${D}  #   Address                                      Balance${RESET}"
        divider
        for i in {0..9}; do
          ADDR="${HH_ACCOUNTS[$i]}"
          BAL_HEX=$(rpc_result "eth_getBalance" "[\"$ADDR\",\"latest\"]")
          BAL=$(wei_to_eth "$BAL_HEX")
          # Colour by balance level
          if python3 -c "exit(0 if float('$BAL') >= 9999 else 1)" 2>/dev/null; then
            BAL_COLOR="${G}$BAL ETH${RESET}"
          elif python3 -c "exit(0 if float('$BAL') > 0 else 1)" 2>/dev/null; then
            BAL_COLOR="${Y}$BAL ETH${RESET}"
          else
            BAL_COLOR="${R}$BAL ETH${RESET}"
          fi
          printf "  ${BOLD}%2d${RESET}  ${D}%s${RESET}  %b\n" "$i" "$ADDR" "$BAL_COLOR"
        done
        pause
        ;;
      2)
        clear
        header "Check Address Balance"
        ask "Enter address (0x...):"
        read -r ADDR
        if [[ "$ADDR" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
          BAL_HEX=$(rpc_result "eth_getBalance" "[\"$ADDR\",\"latest\"]")
          BAL=$(wei_to_eth "$BAL_HEX")
          TX_COUNT_HEX=$(rpc_result "eth_getTransactionCount" "[\"$ADDR\",\"latest\"]")
          TX_COUNT=$(python3 -c "print(int('$TX_COUNT_HEX',16))" 2>/dev/null)
          echo ""
          info "Address    : ${W}$ADDR${RESET}"
          info "Balance    : ${W}$BAL ETH${RESET}"
          info "Nonce (txs): ${W}$TX_COUNT${RESET}"
        else
          fail "Invalid address format"
        fi
        pause
        ;;
      3)
        clear
        echo -e "  ${Y}Watching balances — Ctrl+C to stop${RESET}"
        echo ""
        while true; do
          tput cup 2 0 2>/dev/null || clear
          echo -e "  ${BOLD}Account Balances${RESET}   $(date '+%H:%M:%S')  ${D}(auto-refresh 5s)${RESET}"
          echo ""
          printf "  ${D}  #   Balance (ETH)${RESET}\n"
          divider
          for i in {0..9}; do
            ADDR="${HH_ACCOUNTS[$i]}"
            BAL_HEX=$(rpc_result "eth_getBalance" "[\"$ADDR\",\"latest\"]")
            BAL=$(wei_to_eth "$BAL_HEX")
            ADDR_SHORT="${ADDR:0:10}...${ADDR: -4}"
            printf "  ${BOLD}%2d${RESET}  ${D}%-16s${RESET}  %s ETH\n" "$i" "$ADDR_SHORT" "$BAL"
          done
          sleep 5
        done
        ;;
      4)
        clear
        header "Private Keys & Import Guide"
        warn "PUBLIC test keys — never use on mainnet!"
        echo ""
        echo -e "  ${BOLD}Account #0 — importable by mnemonic OR private key:${RESET}"
        echo -e "  Mnemonic : ${G}test test test test test test test test test test test junk${RESET}"
        echo -e "  Priv key : ${C}${HH_KEYS[0]}${RESET}"
        echo ""
        echo -e "  ${BOLD}Accounts #1-#9 — private key import only:${RESET}"
        echo -e "  ${D}(Use 'Private Key' tab in the app's Import screen)${RESET}"
        echo ""
        for i in {1..9}; do
          BAL_HEX=$(rpc_result "eth_getBalance" "[\"${HH_ACCOUNTS[$i]}\",\"latest\"]" 2>/dev/null)
          BAL=$(wei_to_eth "$BAL_HEX" 2>/dev/null || echo "?")
          echo -e "  ${BOLD}#$i${RESET}  ${D}${HH_ACCOUNTS[$i]}${RESET}  ${G}$BAL ETH${RESET}"
          echo -e "     ${C}${HH_KEYS[$i]}${RESET}"
          echo ""
        done
        pause
        ;;
      0) return ;;
      *) warn "Invalid" ; sleep 1 ;;
    esac
  done
}

# ── 3. Contract Status ────────────────────────────────────────────────────────
menu_contract() {
  clear
  header "Contract Status"
  load_contract

  if [ -z "$CONTRACT" ]; then
    warn "No contract deployed yet. Use option 7 to deploy."
    pause; return
  fi

  if ! node_running; then
    fail "Node offline"
    pause; return
  fi

  info "Contract address : ${W}$CONTRACT${RESET}"
  echo ""

  # Check bytecode exists
  CODE=$(rpc_result "eth_getCode" "[\"$CONTRACT\",\"latest\"]")
  if [ "$CODE" = "0x" ] || [ -z "$CODE" ]; then
    fail "No bytecode at address — contract may not be deployed on this chain"
    warn "This usually means the node was restarted. Redeploy with option 7."
    pause; return
  fi

  CODE_LEN=$(echo -n "$CODE" | wc -c)
  ok "Contract bytecode confirmed (${CODE_LEN} chars)"
  echo ""

  # Contract ETH balance (escrow funds held)
  BAL_HEX=$(rpc_result "eth_getBalance" "[\"$CONTRACT\",\"latest\"]")
  BAL=$(wei_to_eth "$BAL_HEX")
  info "ETH held in escrow : ${W}$BAL ETH${RESET}"

  # Transaction count (number of calls made to contract)
  TX_HEX=$(rpc_result "eth_getTransactionCount" "[\"$CONTRACT\",\"latest\"]")
  TX=$(python3 -c "print(int('$TX_HEX',16))" 2>/dev/null)
  info "Nonce              : ${W}$TX${RESET}"

  # Block the contract was deployed at
  echo ""
  divider
  echo -e "  ${BOLD}Contract Details${RESET}"
  divider
  info "Network  : Hardhat Local (chain ID 31337)"
  info "Deployed : $(cat "$HARDHAT_DIR/.last_deploy_address" 2>/dev/null && echo '' || echo 'unknown')"
  info "Solidity : 0.8.20"
  echo ""
  info "Functions available:"
  echo -e "  ${D}  deposit()         — buyer locks funds into escrow${RESET}"
  echo -e "  ${D}  confirmDelivery() — seller confirms energy sent${RESET}"
  echo -e "  ${D}  confirmReceipt()  — buyer releases funds to seller${RESET}"
  echo -e "  ${D}  raiseDispute()    — buyer raises dispute (24h window)${RESET}"
  echo -e "  ${D}  refund()          — buyer claims refund (48h timeout)${RESET}"
  echo -e "  ${D}  getTradeStatus()  — query trade state${RESET}"

  pause
}

# ── 4. Transaction History ────────────────────────────────────────────────────
menu_transactions() {
  while true; do
    clear
    header "Transaction History"

    if ! node_running; then
      fail "Node offline"
      pause; return
    fi

    echo -e "  ${BOLD}1${RESET}  Recent blocks & transactions"
    echo -e "  ${BOLD}2${RESET}  Transactions for specific address"
    echo -e "  ${BOLD}3${RESET}  Look up transaction by hash"
    echo -e "  ${BOLD}0${RESET}  Back"
    echo ""
    ask "Choose:"
    read -r T

    case "$T" in
      1)
        clear
        header "Recent Blocks"
        LATEST_HEX=$(rpc_result "eth_blockNumber")
        LATEST=$(python3 -c "print(int('$LATEST_HEX',16))" 2>/dev/null)
        START=$(( LATEST > 10 ? LATEST - 10 : 0 ))

        for (( b=LATEST; b>=START; b-- )); do
          HEX=$(python3 -c "print(hex($b))")
          BLOCK_DATA=$(rpc "eth_getBlockByNumber" "[\"$HEX\",true]")
          TX_COUNT=$(echo "$BLOCK_DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('result',{}).get('transactions',[])))" 2>/dev/null)
          TIMESTAMP=$(echo "$BLOCK_DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); t=d.get('result',{}).get('timestamp','0x0'); print(int(t,16))" 2>/dev/null)
          TIME=$(date -d @$TIMESTAMP '+%H:%M:%S' 2>/dev/null || echo "$TIMESTAMP")

          if [ "$TX_COUNT" -gt 0 ] 2>/dev/null; then
            echo -e "  ${W}Block #$b${RESET}  $TIME  ${G}$TX_COUNT tx${RESET}"
            # Show each transaction
            echo "$BLOCK_DATA" | python3 << PYEOF 2>/dev/null
import sys, json
d = json.load(sys.stdin)
txs = d.get('result', {}).get('transactions', [])
for tx in txs:
    frm  = tx.get('from','?')[:10] + '...'
    to   = (tx.get('to') or 'contract creation')
    to   = to[:10] + '...' if len(to) > 10 else to
    val  = int(tx.get('value','0x0'),16)/1e18
    print(f"    → from {frm} to {to}  {val:.4f} ETH  hash: {tx.get('hash','')[:16]}...")
PYEOF
          else
            echo -e "  ${D}Block #$b${RESET}  $TIME  ${D}empty${RESET}"
          fi
        done
        pause
        ;;
      2)
        clear
        header "Address Transactions"
        ask "Enter address:"
        read -r ADDR
        if [[ ! "$ADDR" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
          fail "Invalid address"; pause; continue
        fi
        LATEST_HEX=$(rpc_result "eth_blockNumber")
        LATEST=$(python3 -c "print(int('$LATEST_HEX',16))" 2>/dev/null)
        info "Scanning blocks 0 to $LATEST for $ADDR..."
        ADDR_LOWER=$(echo "$ADDR" | tr '[:upper:]' '[:lower:]')
        FOUND=0
        for (( b=LATEST; b>=0 && FOUND<20; b-- )); do
          HEX=$(python3 -c "print(hex($b))")
          BLOCK_DATA=$(rpc "eth_getBlockByNumber" "[\"$HEX\",true]")
          echo "$BLOCK_DATA" | python3 << PYEOF 2>/dev/null
import sys, json
d = json.load(sys.stdin)
txs = d.get('result', {}).get('transactions', [])
addr = "$ADDR_LOWER"
for tx in txs:
    if tx.get('from','').lower() == addr or (tx.get('to') or '').lower() == addr:
        val = int(tx.get('value','0x0'),16)/1e18
        role = "SENT" if tx.get('from','').lower() == addr else "RECV"
        print(f"  {role}  Block #{int(tx.get('blockNumber','0x0'),16)}  {val:.4f} ETH  {tx.get('hash','')[:20]}...")
        global found; FOUND+=1
PYEOF
        done
        [ $FOUND -eq 0 ] && info "No transactions found for this address"
        pause
        ;;
      3)
        clear
        header "Transaction Lookup"
        ask "Enter transaction hash (0x...):"
        read -r TXHASH
        TX_DATA=$(rpc "eth_getTransactionByHash" "[\"$TXHASH\"]")
        echo "$TX_DATA" | python3 << PYEOF 2>/dev/null
import sys, json
d = json.load(sys.stdin)
tx = d.get('result')
if not tx:
    print("  Transaction not found")
else:
    val = int(tx.get('value','0x0'),16)/1e18
    gas = int(tx.get('gas','0x0'),16)
    gp  = int(tx.get('gasPrice','0x0'),16)/1e9
    bn  = int(tx.get('blockNumber','0x0'),16) if tx.get('blockNumber') else 'pending'
    print(f"  From     : {tx.get('from','?')}")
    print(f"  To       : {tx.get('to') or '(contract creation)'}")
    print(f"  Value    : {val:.6f} ETH")
    print(f"  Gas limit: {gas}")
    print(f"  Gas price: {gp:.1f} Gwei")
    print(f"  Block    : #{bn}")
    print(f"  Nonce    : {int(tx.get('nonce','0x0'),16)}")
    inp = tx.get('input','0x')
    print(f"  Input    : {inp[:66]}{'...' if len(inp)>66 else ''}")
PYEOF
        # Also get receipt
        RCP=$(rpc "eth_getTransactionReceipt" "[\"$TXHASH\"]")
        echo "$RCP" | python3 << PYEOF 2>/dev/null
import sys, json
d = json.load(sys.stdin)
r = d.get('result')
if r:
    status = "SUCCESS" if int(r.get('status','0x0'),16)==1 else "FAILED"
    used = int(r.get('gasUsed','0x0'),16)
    print(f"  Status   : {status}")
    print(f"  Gas used : {used}")
    logs = r.get('logs',[])
    print(f"  Log count: {len(logs)}")
PYEOF
        pause
        ;;
      0) return ;;
    esac
  done
}

# ── 5. Send ETH ───────────────────────────────────────────────────────────────
menu_send() {
  clear
  header "Send ETH Between Accounts"

  if ! node_running; then
    fail "Node offline"; pause; return
  fi

  echo -e "  ${D}Available sender accounts:${RESET}"
  for i in {0..4}; do
    ADDR="${HH_ACCOUNTS[$i]}"
    BAL_HEX=$(rpc_result "eth_getBalance" "[\"$ADDR\",\"latest\"]")
    BAL=$(wei_to_eth "$BAL_HEX")
    printf "  ${BOLD}%d${RESET}  %s  ${G}%s ETH${RESET}\n" "$i" "${ADDR:0:20}..." "$BAL"
  done

  echo ""
  ask "Sender account number (0-9):"
  read -r FROM_IDX
  FROM_ADDR="${HH_ACCOUNTS[$FROM_IDX]}"
  FROM_KEY="${HH_KEYS[$FROM_IDX]}"

  if [ -z "$FROM_ADDR" ]; then
    fail "Invalid account number"; pause; return
  fi

  ask "Recipient address (0x...) or account number (0-9):"
  read -r TO_INPUT

  if [[ "$TO_INPUT" =~ ^[0-9]$ ]]; then
    TO_ADDR="${HH_ACCOUNTS[$TO_INPUT]}"
  elif [[ "$TO_INPUT" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    TO_ADDR="$TO_INPUT"
  else
    fail "Invalid recipient"; pause; return
  fi

  ask "Amount in ETH:"
  read -r AMOUNT

  # Validate amount
  if ! python3 -c "float('$AMOUNT')" 2>/dev/null; then
    fail "Invalid amount"; pause; return
  fi

  echo ""
  info "From    : $FROM_ADDR"
  info "To      : $TO_ADDR"
  info "Amount  : $AMOUNT ETH"
  echo ""
  ask "Confirm? (y/N):"
  read -r CONFIRM
  [[ ! "$CONFIRM" =~ ^[Yy] ]] && return

  # Send via hardhat console
  cd "$HARDHAT_DIR" 2>/dev/null || { fail "Hardhat dir not found"; pause; return; }

  RESULT=$(npx hardhat console --network localhost 2>/dev/null << JSEOF
const [s0,s1,s2,s3,s4,s5,s6,s7,s8,s9] = await ethers.getSigners();
const senders = [s0,s1,s2,s3,s4,s5,s6,s7,s8,s9];
const sender = senders[$FROM_IDX];
const tx = await sender.sendTransaction({
  to: "$TO_ADDR",
  value: ethers.parseEther("$AMOUNT")
});
const receipt = await tx.wait();
console.log("TX_HASH:" + tx.hash);
console.log("GAS_USED:" + receipt.gasUsed.toString());
JSEOF
)

  TX_HASH=$(echo "$RESULT" | grep "TX_HASH:" | cut -d: -f2)
  GAS_USED=$(echo "$RESULT" | grep "GAS_USED:" | cut -d: -f2)

  if [ -n "$TX_HASH" ]; then
    ok "Transaction sent!"
    info "Hash     : $TX_HASH"
    info "Gas used : $GAS_USED"
  else
    fail "Transaction may have failed"
    echo "$RESULT"
  fi

  pause
}

# ── 6. Node Control ───────────────────────────────────────────────────────────
menu_node() {
  while true; do
    clear
    header "Node Control"

    if node_running; then
      NODE_PID=$(cat /tmp/hardhat_node.pid 2>/dev/null || lsof -ti:8545 2>/dev/null | head -1)
      ok "Node is RUNNING  PID: ${NODE_PID:-unknown}"
    else
      fail "Node is OFFLINE"
    fi

    echo ""
    echo -e "  ${BOLD}1${RESET}  Start node"
    echo -e "  ${BOLD}2${RESET}  Stop node"
    echo -e "  ${BOLD}3${RESET}  Restart node"
    echo -e "  ${BOLD}4${RESET}  View node logs (last 30 lines)"
    echo -e "  ${BOLD}5${RESET}  Follow node logs live"
    echo -e "  ${BOLD}0${RESET}  Back"
    echo ""
    ask "Choose:"
    read -r N

    case "$N" in
      1)
        if node_running; then
          warn "Node already running"
        else
          cd "$HARDHAT_DIR" 2>/dev/null || { fail "Hardhat dir not found"; pause; continue; }
          info "Starting node..."
          cd "$HARDHAT_DIR" > /dev/null 2>&1
          nohup npx hardhat node > /tmp/hardhat_node.log 2>&1 &
          echo $! > /tmp/hardhat_node.pid
          sleep 3
          node_running && ok "Node started (PID $(cat /tmp/hardhat_node.pid))" || fail "Failed to start"
        fi
        pause
        ;;
      2)
        if ! node_running; then
          warn "Node not running"
        else
          PID=$(lsof -ti:8545 2>/dev/null | head -1)
          [ -n "$PID" ] && kill "$PID" && ok "Node stopped" || fail "Could not stop node"
          rm -f /tmp/hardhat_node.pid
        fi
        pause
        ;;
      3)
        info "Restarting..."
        PID=$(lsof -ti:8545 2>/dev/null | head -1)
        [ -n "$PID" ] && kill "$PID" && sleep 2
        cd "$HARDHAT_DIR" > /dev/null 2>&1
        nohup npx hardhat node > /tmp/hardhat_node.log 2>&1 &
        echo $! > /tmp/hardhat_node.pid
        sleep 3
        node_running && ok "Node restarted" || fail "Failed to restart"
        warn "Chain has been reset — redeploy contract (option 7)"
        pause
        ;;
      4)
        clear
        header "Node Logs (last 30 lines)"
        tail -30 /tmp/hardhat_node.log 2>/dev/null || fail "No log file found at /tmp/hardhat_node.log"
        pause
        ;;
      5)
        echo -e "  ${Y}Following logs — Ctrl+C to stop${RESET}"
        tail -f /tmp/hardhat_node.log 2>/dev/null || fail "No log file"
        ;;
      0) return ;;
    esac
  done
}

# ── 7. Deploy Contract ────────────────────────────────────────────────────────
menu_deploy() {
  clear
  header "Deploy Contract"

  if ! node_running; then
    fail "Node not running — start it first (option 6)"
    pause; return
  fi

  if [ -n "$CONTRACT" ]; then
    info "Currently deployed at: $CONTRACT"
    echo ""
    ask "Redeploy? This will create a new contract address. (y/N):"
    read -r CONF
    [[ ! "$CONF" =~ ^[Yy] ]] && return
  fi

  if [ ! -f "$HARDHAT_DIR/contracts/EnergyEscrow.sol" ]; then
    fail "EnergyEscrow.sol not found in $HARDHAT_DIR/contracts/"
    pause; return
  fi

  info "Compiling and deploying..."
  cd "$HARDHAT_DIR" > /dev/null 2>&1 || { fail "Hardhat dir not found"; pause; return; }
  # Strip ANSI codes and suppress Node version warnings from output
  DEPLOY_OUT=$(npx hardhat run scripts/deploy.js --network localhost 2>&1 | \
    grep -v 'WARNING:' | grep -v '^$' | sed 's/\x1b\[[0-9;]*m//g')

  # Parse address — handle both output formats:
  #   'CONTRACT_ADDRESS:0x...'  (ev2ev_hardhat_setup.sh format)
  #   'Contract address : 0x...' (manual deploy.js format)
  NEW_CONTRACT=$(echo "$DEPLOY_OUT" | grep -oP '0x[0-9a-fA-F]{40}' | tail -1)

  # Fallback: read from file written by deploy.js
  if [ -z "$NEW_CONTRACT" ] && [ -f "$HARDHAT_DIR/.last_deploy_address" ]; then
    NEW_CONTRACT=$(cat "$HARDHAT_DIR/.last_deploy_address")
  fi

  if [ -n "$NEW_CONTRACT" ]; then
    CONTRACT="$NEW_CONTRACT"
    echo "$CONTRACT" > "$CONTRACT_FILE"
    ok "Deployed at: $CONTRACT"
    echo ""
    warn "Update wallet_service.dart with this address:"
    echo -e "  ${C}static const String contractAddress = '$CONTRACT';${RESET}"
    echo ""
    info "Auto-patching Flutter app..."
    WALLET_SERVICE="$HOME/Desktop/PROJECT FINAL/lib/services/wallet_service.dart"
    if [ -f "$WALLET_SERVICE" ]; then
      python3 -c "
import re
with open('$WALLET_SERVICE', 'r') as f: txt = f.read()
txt = re.sub(
    r\"static const String contractAddress =\\s*'[^']*';\",
    \"static const String contractAddress = '$CONTRACT'; // auto-patched\",
    txt
)
with open('$WALLET_SERVICE', 'w') as f: f.write(txt)
"
      ok "wallet_service.dart patched"
    else
      warn "wallet_service.dart not found — patch manually"
    fi

    # ── Auto-generate QR after deploy ──────────────────────────────
    echo ""
    divider
    LOCAL_IP=$(ip addr show | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+' | grep -v '^127\.' | head -1)
    [ -z "$LOCAL_IP" ] && LOCAL_IP=$(hostname -I | awk '{print $1}')
    RPC_QR="http://$LOCAL_IP:8545"
    MNEMONIC="test test test test test test test test test test test junk"
    QR_PAYLOAD="{\"rpc\":\"$RPC_QR\",\"chainId\":31337,\"contract\":\"$CONTRACT\",\"network\":\"Hardhat Local\",\"symbol\":\"ETH\",\"mnemonic\":\"$MNEMONIC\",\"account\":\"${HH_ACCOUNTS[0]}\"}"

    if python3 -c "import qrcode" 2>/dev/null; then
      echo -e "  ${BOLD}Scan QR to connect the app:${RESET}"
      echo ""
      python3 << PYEOF
import qrcode
payload = r"""$QR_PAYLOAD"""
qr = qrcode.QRCode(version=None, error_correction=qrcode.constants.ERROR_CORRECT_L, box_size=1, border=1)
qr.add_data(payload.strip())
qr.make(fit=True)
qr.print_ascii(invert=True)
PYEOF
      echo ""
      echo -e "  ${D}RPC: $RPC_QR   Contract: ${CONTRACT:0:10}...${CONTRACT: -4}${RESET}"
    else
      info "Install qrcode for QR display: pip3 install qrcode --break-system-packages"
    fi
  else
    fail "Deployment failed"
    echo "$DEPLOY_OUT"
  fi

  pause
}

# ── 8. QR Code ────────────────────────────────────────────────────────────────
menu_qr() {
  clear
  header "Generate QR Code"
  load_contract

  if [ -z "$CONTRACT" ]; then
    warn "No contract deployed. Deploy first (option 7)."
    pause; return
  fi

  # Detect IP
  LOCAL_IP=$(ip addr show | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+' | grep -v '^127\.' | head -1)
  [ -z "$LOCAL_IP" ] && LOCAL_IP=$(hostname -I | awk '{print $1}')

  echo -e "  ${D}Detected IP: $LOCAL_IP${RESET}"
  ask "Use $LOCAL_IP? (Enter = yes, or type different IP):"
  read -r IP_INPUT
  [ -n "$IP_INPUT" ] && LOCAL_IP="$IP_INPUT"

  RPC_QR="http://${LOCAL_IP}:8545"
  MNEMONIC="test test test test test test test test test test test junk"
  PAYLOAD="{\"rpc\":\"$RPC_QR\",\"chainId\":31337,\"contract\":\"$CONTRACT\",\"network\":\"Hardhat Local\",\"symbol\":\"ETH\",\"mnemonic\":\"$MNEMONIC\",\"account\":\"${HH_ACCOUNTS[0]}\"}"

  echo ""

  if python3 -c "import qrcode" 2>/dev/null; then
    python3 << PYEOF
import qrcode
payload = r"""$PAYLOAD"""
qr = qrcode.QRCode(version=None, error_correction=qrcode.constants.ERROR_CORRECT_L, box_size=1, border=1)
qr.add_data(payload.strip())
qr.make(fit=True)
print("  Scan with EV2EV app → Wallet → Switch Accounts → Hardhat Local → QR button\n")
qr.print_ascii(invert=True)
PYEOF
  else
    warn "qrcode library not installed. Showing payload only."
    info "Payload: $PAYLOAD"
  fi

  echo ""
  divider
  info "RPC URL   : ${W}$RPC_QR${RESET}"
  info "Chain ID  : ${W}31337${RESET}"
  info "Contract  : ${W}$CONTRACT${RESET}"
  echo ""
  info "Account #0: ${W}${HH_ACCOUNTS[0]}${RESET}"
  info "Account #1: ${W}${HH_ACCOUNTS[1]}${RESET}"

  pause
}

# ── 9. Settings ───────────────────────────────────────────────────────────────
menu_settings() {
  while true; do
    clear
    header "Settings"
    load_contract

    info "RPC URL    : ${W}$RPC${RESET}"
    info "Contract   : ${W}${CONTRACT:-not set}${RESET}"
    info "Hardhat dir: ${W}$HARDHAT_DIR${RESET}"
    echo ""
    echo -e "  ${BOLD}1${RESET}  Change RPC URL"
    echo -e "  ${BOLD}2${RESET}  Set contract address manually"
    echo -e "  ${BOLD}3${RESET}  Show all private keys"
    echo -e "  ${BOLD}4${RESET}  Reset chain (wipe all transactions)"
    echo -e "  ${BOLD}0${RESET}  Back"
    echo ""
    ask "Choose:"
    read -r S

    case "$S" in
      1)
        ask "New RPC URL (current: $RPC):"
        read -r NEW_RPC
        [ -n "$NEW_RPC" ] && RPC="$NEW_RPC" && ok "RPC set to $RPC"
        pause
        ;;
      2)
        ask "Contract address (0x...):"
        read -r NEW_CONTRACT
        if [[ "$NEW_CONTRACT" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
          echo "$NEW_CONTRACT" > "$CONTRACT_FILE"
          CONTRACT="$NEW_CONTRACT"
          ok "Contract set to $CONTRACT"
        else
          fail "Invalid address"
        fi
        pause
        ;;
      3)
        clear
        header "Accounts, Keys & Import Info"
        warn "PUBLIC test keys only — never use on mainnet!"
        echo ""
        # All Hardhat accounts share one master mnemonic, different derivation paths
        echo -e "  ${BOLD}Master Mnemonic (Account #0 only — standard path m/44'/60'/0'/0/0):${RESET}"
        echo -e "  ${G}test test test test test test test test test test test junk${RESET}"
        echo ""
        echo -e "  ${D}Accounts #1-#9 cannot be imported by mnemonic in the app.${RESET}"
        echo -e "  ${D}Use the Private Key tab in the app's Import screen instead.${RESET}"
        echo ""
        divider
        echo -e "  ${BOLD}  #  Address                                       Private Key (paste into app)${RESET}"
        divider
        for i in {0..9}; do
          echo -e "  ${BOLD}  $i${RESET}  ${D}${HH_ACCOUNTS[$i]}${RESET}"
          echo -e "     ${C}${HH_KEYS[$i]}${RESET}"
          if [ "$i" -eq 0 ]; then
            echo -e "     ${G}↑ also importable by mnemonic above${RESET}"
          fi
          echo ""
        done
        echo ""
        echo -e "  ${BOLD}How to import in EV2EV app:${RESET}"
        echo -e "  1. Wallet → Switch Accounts → Import another account"
        echo -e "  2. For Account #0: use ${G}Recovery Phrase${RESET} tab, paste mnemonic above"
        echo -e "  3. For Accounts #1-#9: use ${C}Private Key${RESET} tab, paste the key shown"
        pause
        ;;
      4)
        ask "This stops and restarts the node, wiping all transactions. Continue? (y/N):"
        read -r CONF
        if [[ "$CONF" =~ ^[Yy] ]]; then
          PID=$(lsof -ti:8545 2>/dev/null | head -1)
          [ -n "$PID" ] && kill "$PID" && sleep 2
          cd "$HARDHAT_DIR" > /dev/null 2>&1
          nohup npx hardhat node > /tmp/hardhat_node.log 2>&1 &
          echo $! > /tmp/hardhat_node.pid
          sleep 3
          node_running && ok "Chain reset. Node restarted." || fail "Failed to restart"
          warn "Redeploy your contract now (option 7)"
          rm -f "$CONTRACT_FILE"
          CONTRACT=""
        fi
        pause
        ;;
      0) return ;;
    esac
  done
}

# ── Entry point ───────────────────────────────────────────────────────────────
load_contract
main_menu