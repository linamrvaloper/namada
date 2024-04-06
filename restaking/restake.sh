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
    else
        echo "Current balance: $balance"
    fi
    return 0  # Indicate success
}


# Function to restake validator rewards
validator_restake() {
  echo "Attempting to restake validator rewards..."
  val_reward=$(echo "$(namadac rewards --validator "$VALIDATOR_ADDRESS")" | grep -o '[0-9]\+\.[0-9]\+')
  echo "Validator rewards available for claiming: $val_reward"
  if check_balance && [[ $(echo "$val_reward > $min_bond" | bc) -eq 1 ]] && [[ $(echo "$balance + $val_reward > $min_balance + $min_bond" | bc) -eq 1 ]]; then
  echo "Proceeding to claim rewards..."
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
          echo "Successfully bonded "$bond_amount" NAM to validator "$VALIDATOR_ADDRESS". (self-bond)"
          echo "_________________________________________________________________________"
        else
          echo "Error: Failed to bond."
          return 1
        fi
      else
        echo "Error: Bond amount ($bond_amount) is less than the minimum bond ($min_bond)."
        return 1
      fi
    fi
  else
    echo "Error: Pre-conditions for validator restake not met."
    return 1
  fi
  return 0
}


wallet_restake() {
    echo "Wallet restaking should be here..."
    # ...
}

# Infinite loop to repeat the main loop every 4 hours
while true; do
    validator_restake
    echo "_________________________________________________________________________"
    wallet_restake
    echo "_________________________________________________________________________"
    echo "Sleeping for 1 hour..."
    echo "_________________________________________________________________________"
    echo "_________________________________________________________________________"
    sleep 1h
 done
