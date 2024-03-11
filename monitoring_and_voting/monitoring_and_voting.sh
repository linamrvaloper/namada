#!/bin/bash

read -s -p "Enter your decryption password: " password

# Change if your service name differs
nam_service="namadad"

# Change to true if you want to allow notifications via Telegram
telegram_enable=false
# Telegram chat ID
telegram_chat_id="<telegram_chat_id>"
# Telegram bot token
telegram_bot_token="<telegram_bot_token>"

# Function to send a message to Telegram
send_telegram_message() {
  if [ "$telegram_enable" == "false" ]; then
    return  # Exit the function if notifications are disabled
  fi

  message="$1"
  # Use curl to send a POST request with the message to Telegram
  curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" \
       -d "chat_id=$telegram_chat_id" \
       -d "text=$message"
}

# Function to check balance. Min balance can be set as needed
check_balance() {
    min_balance=20
    balance=$(echo "$(namadac balance --owner $WALLET --node $NODE)" | grep -oP 'naan: \K\d+')
    if [[ $balance -lt $min_balance ]]; then
        echo "Namada SE >> voting >> balance is less than minimum of $min_balance. Current balance: $balance."
        send_telegram_message "Namada SE >> balance of $WALLET is less than minimum of $min_balance. Current balance: $balance.
You should refill the balance."
        return 1  # Indicate failure due to low balance
    fi
    return 0  # Indicate success
}

# Creating a file for the list of voted proposals if there is no such already
if [ ! -f voted.txt ]; then
    touch voted.txt
    echo "Empty file voted.txt for the list of voted proposals created."
    echo "-----------------------------------------------------------------"
else
    echo "File voted.txt already exists."
    echo "-----------------------------------------------------------------"
fi


# Main loop for voting
main_loop() {
    local i=260 # Proposal id to begin with - has to be set once before running the script for the first time
    local voted_ids=()
    local error_ids=()
    local voting_summary=""
    local error_summary=""
    
    while true; do
        if grep -q "^$i$" voted.txt; then
            echo "Proposal $i is already voted for. Next proposal..."
            echo "-----------------------------------------------------------------"
        else
            start_epoch=$(echo "$(namadac query-proposal --node $NODE --proposal-id $i 2>/dev/null)" | grep -oP 'Start Epoch: \K\d+')
            end_epoch=$(echo "$(namadac query-proposal --node $NODE --proposal-id $i 2>/dev/null)" | grep -oP 'End Epoch: \K\d+')
            last_epoch=$(echo "$(namadac epoch --node $NODE)" | grep -oP 'Last committed epoch: \K\d+')
            proposal_status=$(echo "$(namadac query-proposal --node $NODE --proposal-id $i 2>/dev/null)" | grep "Status: " | awk '{print $2}')
            echo "Last committed epoch=${last_epoch}. Checking proposal $i... Proposal status is $proposal_status."
            echo "-----------------------------------------------------------------"
            
            if [[ -z $proposal_status ]]; then
                echo "Proposal $i doesn't exist yet - that's all for now."
                echo "-----------------------------------------------------------------"
                
                # Preparing and sending the final message with the voting summary
                # Check if any proposals have been voted on
                if [ ${#voted_ids[@]} -eq 0 ]; then
                    voting_summary="No proposals have been voted for."
                else
                    printf -v voted_cs '%s,' "${voted_ids[@]}"
                    voting_summary="Voted for proposals: ${voted_cs%,}."
                fi

                # Check if any errors occurred during voting
                if [ ${#error_ids[@]} -eq 0 ]; then
                    error_summary="No errors occurred during the voting process."
                else
                    printf -v error_cs '%s,' "${error_ids[@]}"
                    error_summary="Errors occurred on proposals: ${error_cs%,}."
                fi
                
                final_message="Namada SE voting results
>> $voting_summary
>> $error_summary"
                echo "$final_message"
                send_telegram_message "$final_message"
                
                # Escaping the loop
                break
            
            elif [[ $proposal_status == "ended" ]]; then
                echo "$i" >> voted.txt
                echo "Voting for proposal $i has already ended in epoch $end_epoch. Added as voted to skip next time. Next proposal..."
                echo "-----------------------------------------------------------------"
            fi

            if [[ $proposal_status == "on-going" ]]; then
                echo "Proposal $i started in epoch $start_epoch and is on-going. Starting to vote..."

                if check_balance; then
                    echo "The balance is $balance"
                    vote_output=$(expect -c "set timeout -1
                    spawn namadac vote-proposal --memo $MEMO --vote yay --address $WALLET --node $NODE --proposal-id $i
                    expect \"Enter your decryption password: \"
                    send -- \"$password\r\"
                    expect eof")

                    echo "$vote_output"

                    if echo "$vote_output" | grep -q "Transaction was successfully applied"; then
                        echo "Proposal $i successfully voted."
                        echo "$i" >> voted.txt  # Add proposal id to voted.txt
                        voted_ids+=("$i")
                        echo "-----------------------------------------------------------------"
                    else
                        echo "Error occurred on proposal $i."
                        error_ids+=("$i")
                        echo "-----------------------------------------------------------------"
                    fi
                else
                    echo "Please, refill the balance. Voting will continue in 4h."
                    echo "-----------------------------------------------------------------"
                    break
                fi
            fi
        fi
        ((i += 1))
    done
}

# Infinite loop to repeat the main loop every 4 hours
while true; do
    if echo "$(systemctl status $nam_service)" | grep -q "Active: active (running)"; then
        echo "Namada SE node is active."
        echo "-----------------------------------------------------------------"
        main_loop
    else
        echo "Namada SE node not responding/running. Check and restart the node. Voting will continue in 4h."
        echo "-----------------------------------------------------------------"
        send_telegram_message "Namada SE node not responding/running. Check and restart the node. Voting will continue in 4h."
    fi
    echo "Sleeping for 4h..."
    echo "-----------------------------------------------------------------"
    echo "-----------------------------------------------------------------"
    sleep 4h
 done
