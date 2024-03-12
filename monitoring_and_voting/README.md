# Node and balance monitoring + voting script

***Script functionality:***
- Tracks node status (every 4h)
- Tracks wallet balance (every 4h)
- Finds on-going proposals and votes on all types of them (every 4h)

***Optional:***
- Notifications via Telegram if node is not running or if the balance is less than min_balance
- Voting summaries on Telegram

## Configure the environment
**Set variables**
- WALLET - the alias for the wallet you want to monitor
~~~
echo "export MEMO="your_tpknam_address"" >> $HOME/.bash_profile
echo "export WALLET="wallet"" >> $HOME/.bash_profile
~~~

## Download the script
~~~
cd $HOME
wget -O monitoring_and_voting.sh https://raw.githubusercontent.com/linamrvaloper/namada-se/main/monitoring_and_voting/monitoring_and_voting.sh
chmod +x monitoring_and_voting.sh
~~~

## Optional: Configure Telegram alerting
If you want to get alerts and summaries via Telegram, you need to create a bot and a group with it. You can use [@BotFather](https://t.me/BotFather) for this purpose.
- Here are the [instructions](https://sematext.com/docs/integration/alerts-telegram-integration/)
- How to get [chat id](https://stackoverflow.com/questions/32423837/telegram-bot-how-to-get-a-group-chat-id)

After creating telegram bot and group, specify the variables in the monitoring_and_voting.sh:
- enable Telegram notifications ```telegram_enable=true```
- set values for ```telegram_chat_id``` and ```telegram_bot_token```
~~~
nano monitoring_and_voting.sh
~~~

## Run the script 
Create a tmux session
~~~
tmux new -s monitoring_and_voting
~~~

Start the script
~~~
bash monitoring_and_voting.sh
~~~

If you want to disconnect the session, use ```CTRL+B D```. 

If you want to kill session:
~~~
tmux kill-session -t monitoring_and_voting
~~~

If you want to connect active session, you can run:
~~~
tmux attach -t monitoring_and_voting
~~~


Voilà! Enjoy the script ;)
