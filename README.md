# ♠️ CallBreak – Multiplayer Card Game in Elixir

CallBreak is a web-based version of the classic South Asian card game, built with Elixir. This project brings the excitement of the real-world game into your browser, supporting multiple players in a turn-based format.

---

## 🎮 Game Overview

CallBreak is a strategic trick-taking card game played by 4 players. Each round consists of calling (bidding) and playing tricks. Players aim to win the number of tricks they called, and scoring is based on how well they perform against their bid.

This project replicates the same experience in a multiplayer online setting, with real-time updates and automatic rule enforcement.

---

## ✨ Features

- 🔁 Turn-based multiplayer gameplay with proper game state management  
- 🧠 Accurate implementation of CallBreak rules  
- 🌐 Real-time communication using WebSockets  
- 🃏 Automatic card shuffling, dealing, and scoring  
- 🧩 Channel-based architecture for clean game state management  
- 🛠️ Built using Elixir and Phoenix for performance and scalability  

---

## Current UI

This is the current UI. It only exists for testing purpose. I need to completly revamp the frontend. But it works.


![image](https://github.com/user-attachments/assets/15541414-c8d2-4aca-badd-bf93a5608bd9)


## ⚙️ Getting Started

To run the project locally, follow these steps:

```bash
git clone https://github.com/mayhem49/callbreak.git
cd callbreak
mix setup
mix phx.server
```

Then open your browser and navigate to:  
👉 [http://localhost:4000](http://localhost:4000)

Make sure you have **Elixir**, **Erlang**, and **Node.js** installed on your system.

---

## 🧩 Tech Stack

- **Elixir** – Functional language ideal for scalable, concurrent systems  
- **Phoenix Framework** – Web framework for building real-time apps  
- **WebSockets (Phoenix Channels)** – Enables real-time communication between players  
- **LiveView** – For interactive UI updates without writing JS  
- **TailwindCSS** *(if configured)* – For modern UI styling  
---
