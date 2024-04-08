# Validator restaking script

***Script functionality:***
- Profit Optimization: Automatically claims and restakes validator & delegation rewards, compounding the stake and increasing potential earnings
- Security Enhancement: Supports network security by contributing to proof-of-stake

***Operational Algorithm:***
- Claims any available rewards for the validator and bonds them back to the validator, enhancing their total stake
- Identifies and claims rewards for all bonded tokens across all validators delegated to
- Rebonds these rewards and some additional balance to your validator
- Additionally monitors the wallet balance to keep it higher than customizable minimum threshold or not to take any actions if the balance is too low
- Takes into account the claiming/bonding appropriateness based on the amount available for claiming/bonding and transaction fees

## Configure the environment
**Install dependencies if needed**
~~~
sudo apt update && sudo apt upgrade -y
sudo apt install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y
~~~

**Set variables**
- `WALLET` - the alias for the wallet you are delegating (bonding) from
- `VALIDATOR_ADDRESS` - address of your validator to restake the rewards to
~~~
echo "export MEMO="your_tpknam_address"" >> $HOME/.bash_profile
echo "export WALLET="<YOUR_WALLET_NAME>"" >> $HOME/.bash_profile
echo "export VALIDATOR_ADDRESS="<YOUR_VALIDATOR_ADDRESS>"" >> $HOME/.bash_profile
source $HOME/.bash_profile
~~~

## Download the script
~~~
cd $HOME
wget -O restake.sh https://raw.githubusercontent.com/linamrvaloper/namada-se/main/restaking/restake.sh
chmod +x restake.sh
~~~

## Customize some variables if necessary

After creating telegram bot and group, specify the variables in the monitoring_and_voting.sh:
- `stop_balance` (50 by default) - wallet balance below which no actions will be taken
- `min_balance` (3000 by default) - the balance you want to keep on your wallet after restaking
- `min_restake` (30 by default) - restaking minimum threshold
- `min_claim` (30 by default) - claiming miminum threshold
~~~
nano restake.sh
~~~

## Run the script 
Create a tmux session
~~~
tmux new -s restake
~~~

Start the script in tmux session
~~~
bash restake.sh
~~~

If you want to disconnect the session, use `CTRL+B D`. 

If you want to connect active session:
~~~
tmux attach -t restake
~~~

If you want to kill the session:
~~~
tmux kill-session -t restake
~~~


_Voilà! Enjoy the script ;)_
