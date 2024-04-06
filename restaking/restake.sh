#!/bin/bash

read -s -p "Enter your wallet decryption password (for restaking): " wallet_password
echo "" 
read -s -p "Enter your validator decryption password (for self-restaking): " val_password
echo "" 

# Customize thresholds if needed
stop_balance=20
min_balance=1000
min_restake=30
min_claim=30

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


# Function to restake your validator rewards
validator_restake() {
  echo "Attempting to restake your validator rewards..."
  val_reward=$(echo "$(namadac rewards --validator "$VALIDATOR_ADDRESS")" | grep -o '[0-9]\+\.[0-9]\+')
  echo "Validator rewards available for claiming: $val_reward"
  if check_balance && (( $(echo "$val_reward > $min_restake" | bc -l) )); then
  echo "Proceeding to claim rewards..."
    claim_output=$(expect -c "set timeout -1
                  spawn namadac claim-rewards --validator "$VALIDATOR_ADDRESS" --memo "$MEMO"
                  expect \"Enter your decryption password: \"
                  send -- \"$val_password\r\"
                  expect eof")
    if echo "$claim_output" | grep -q "Transaction was successfully applied"; then
      echo "Successfully claimed $val_reward naan."
      echo "_________________________________________________________________________"
      val_balance=$(echo "$(namadac balance --owner $VALIDATOR_ADDRESS)" | grep -oP 'naan: \K\d+')
      selfbond_output=$(expect -c "set timeout -1
                    spawn namadac bond --validator "$VALIDATOR_ADDRESS" --amount "$val_balance" --memo "$MEMO"
                    expect \"Enter your decryption password: \"
                    send -- \"$val_password\r\"
                    expect eof")
        if echo "$selfbond_output" | grep -q "Transaction was successfully applied"; then
          echo "Successfully bonded "$val_balance" naan to validator "$VALIDATOR_ADDRESS". (self-bond)"
          echo "_________________________________________________________________________"
        else
          echo "Error: Failed to bond."
          return 1
        fi
    else
        echo "Error: Failed to claim."
        return 1
    fi
  else
     echo "Reward amount ($val_reward) is less than the minimum restake ($min_restake)."
     return 1
  fi
  return 0
}


# Function to collect all rewards from wallet delegations and restake them to your validator
wallet_restake() {
    echo "Collecting validator addresses delegated to..."
    # Extract all validator addresses delegated to
    bonds_list_output=$(echo "$(namadac bonds --owner $WALLET)")
    echo "$bonds_list_output" | grep "Delegations from" | sed -n 's/.* to \(\S*\):.*/\1/p' > delegation_addresses.txt
    # Read addresses into an array
    addresses=()
    mapfile -t addresses < delegation_addresses.txt
    rm delegation_addresses.txt
    
    # Total claimed rewards counter
    total_claimed=0

    echo "Claiming delegation rewards..."
    # Loop through each validator address
    for validator in "${addresses[@]}"; do
        if check_balance; then
            # Check the rewards
            bond_reward=$(echo "$(namadac rewards --validator "$validator" --source "$WALLET")" | grep -o '[0-9]\+\.[0-9]\+')
    
            # Check if the rewards exceed the minimum claim amount
            if (( $(echo "$bond_reward > $min_claim" | bc -l) )); then
                # Claim the rewards
                claim_output=$(expect -c "set timeout -1
                      spawn namadac claim-rewards --validator "$validator" --memo "$MEMO"
                      expect \"Enter your decryption password: \"
                      send -- \"$wallet_password\r\"
                      expect eof")
                if echo "$claim_output" | grep -q "Transaction was successfully applied"; then
                    echo "Successfully claimed $bond_reward naan from validator $validator."
                    echo "_________________________________________________________________________"
                else
                    echo "Error: Failed to claim."
                    return 1
                fi
            # Add the claimed rewards to the total
            total_claimed=$(echo "$total_claimed + $bond_reward" | bc -l)
            else
                echo "Reward amount ($bond_reward) from validator $validator is less than the minimum claim ($min_claim)."
                return 1
            fi
        fi
    done

    # After claiming rewards, bond them to the specified validator
    if check_balance; then
        if (($(echo "$balance + $total_claimed > $min_balance + $min_restake" | bc -l) )); then
        echo "Bonding to your validator..."
        # Use expect to automate interaction with namadac bond command
        bond_output=$(expect -c "
            set timeout -1
            spawn namadac bond --validator "$VALIDATOR_ADDRESS" --source "$WALLET" --amount "$total_claimed" --memo "$MEMO"
            expect \"Enter your decryption password: \"
            send -- \"$wallet_password\r\"
            expect eof
        ")
        if echo "$bond_output" | grep -q "Transaction was successfully applied"; then
          echo "Successfully bonded rewards of "$total_claimed" naan to validator "$VALIDATOR_ADDRESS"."
          echo "_________________________________________________________________________"
        else
          echo "Error: Failed to bond."
          return 1
        fi
        else
            echo "Insufficient balance for bonding. Minimum left balance should be $min_balance, and the current balance is $balance."
            return 1
        fi
    return 0
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
