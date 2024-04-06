#!/bin/bash

read -s -p "Enter your wallet decryption password (for restaking): " wallet_password
echo "" 
read -s -p "Enter your validator decryption password (for self-restaking): " val_password
echo "" 

# Customize thresholds if needed
stop_balance=20
min_balance=1000
min_bond=10

# Function to check balance. Min balance can be reset as needed
check_balance() {
    balance=$(echo "$(namadac balance --owner $WALLET)" | grep -oP 'naan: \K\d+')
    if [[ $balance -lt $stop_balance ]]; then
        echo "The balance of $WALLET is less than minimum of $stop_balance. Current balance: $balance."
        return 1  # Indicate failure due to low balance
    fi
    return 0  # Indicate success
}


# Function to restake validator rewards
validator_restake() {
  val_reward=$(echo "$(namadac rewards --validator "$VALIDATOR_ADDRESS")" | grep -o '[0-9]\+\.[0-9]\+')
  if check_balance && [[ $(echo "$val_reward > $min_bond" | bc) -eq 1 ]] && [[ $(echo "$balance + $val_reward > $min_balance + $min_bond" | bc) -eq 1 ]]; then
    claim_output=$(expect -c "set timeout -1
                  spawn namadac claim-rewards --validator "$VALIDATOR_ADDRESS" --memo "$MEMO"
                  expect \"Enter your decryption password: \"
                  send -- \"$val_password\r\"
                  expect eof")
    if echo "$claim_output" | grep -q "Transaction was successfully applied"; then
      echo "Successfully claimed $val_reward NAM."
      echo "_________________________________________________________________________"
    fi
    
    if check_balance; then
      bond_amount=$((balance - min_balance))
      if [[ $(echo "$bond_amount > $min_bond" | bc) -eq 1 ]]; then
        bond_output=$(expect -c "set timeout -1
                    spawn namadac bond --validator "$VALIDATOR_ADDRESS" --amount "$bond_amount" --memo "$MEMO"
                    expect \"Enter your decryption password: \"
                    send -- \"$val_password\r\"
                    expect eof")
        if echo "$bond_output" | grep -q "Transaction was successfully applied"; then
          echo "Successfully bonded "$bond_amount" NAM to validator "$VALIDATOR_ADDRESS"."
          echo "_________________________________________________________________________"
        fi            
      fi
    fi
    return 0
  fi
  return 1
}


wallet_restake() {
# ...
}

# Infinite loop to repeat the main loop every 4 hours
while true; do
    validator_restake
    wallet_restake
    echo "Sleeping for 1 hour..."
    echo "-----------------------------------------------------------------"
    sleep 1h
 done
