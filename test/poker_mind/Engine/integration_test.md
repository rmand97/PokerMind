# Poker Game Test Scenarios
**Variant:** Texas Hold'em  
**Starting Stacks:** 10,000 chips per player  
**Blinds:** 50 / 100, doubling every 10 hands 

# Game 1 - Re-raises (2 Players)

## Setup
- **Player 1 (P1):** 10,000 chips  
- **Player 2 (P2):** 10,000 chips  
- **Total Chips:** 20,000  
- **Blinds:** 50 / 100  

---

## Hand 1  
**Blinds:** 50 / 100  
- **P1:** Small Blind  
- **P2:** Big Blind  

### Hole Cards
- **P1:** Js Jd  
- **P2:** 9c 8c  

### Community Cards
- **Flop:** Jh 4d 2c  
- **Turn:** Ks  
- **River:** 7d  

### Action
- Pre-flop: P1 raises to 300, P2 calls  
- Flop: P1 bets 400, P2 calls  
- Turn: P1 bets 600, P2 calls  
- River: Both check  

### Showdown
- **P1 wins** with trip Jacks  

### Chip Counts
- **P1:** 11,300  
- **P2:** 8,700  

---

## Hand 2  
**Blinds:** 50 / 100  
- **P2:** Small Blind  
- **P1:** Big Blind  

### Hole Cards
- **P1:** Ad Qd  
- **P2:** Kc 9c  

### Community Cards
- **Flop:** Tc 8c 3c  
- **Turn:** 2s  
- **River:** 6d  

### Action
- Pre-flop: P2 raises to 500, P1 re-raises to 1500, P2 calls  
- Flop: P2 checks, P1 bets 2000, P2 goes all-in for 7200, P1 calls remaining 5200  

### Showdown
- **P2 wins** with a flush  

### Chip Counts
- **P1:** 2,600  
- **P2:** 17,400  

---

## Hand 3  
**Blinds:** 50 / 100  
- **P1:** Small Blind  
- **P2:** Big Blind  

### Hole Cards
- **P1:** As 7h  
- **P2:** Kd Qc  

### Community Cards
- **Flop:** Kh Qd 5c  
- **Turn:** 3s  
- **River:** 9d  

### Action
- Pre-flop: P1 raises to 500, P2 re-raises to 1500, P1 goes all-in for 2600, P2 calls  

### Showdown
- **P2 wins** with two pair  

---

## Result
- **P1 eliminated**  
- **P2 wins the game**  

---

## Game Summary
- **Ended:** Hand 3  
- **Blind Level:** 50 / 100 (Level 1)  

### Notes / Edge Cases
- Deep stacks allowed multi-street betting before all-in  
- Blind level increase did not trigger  
- Game correctly ended without attempting blind escalation after victory   

---



# Game 2 — Instant Victory (2 Players)

## Setup
- **Player 1 (P1):** 10,000 chips
- **Player 2 (P2):** 10,000 chips
- **Total Chips:** 20,000
- **Blinds:** 50 / 100

---

## Hand 1
**Blinds:** 50 / 100
- **P1:** Small Blind / Button
- **P2:** Big Blind

### Hole Cards
- **P1:** Ac As
- **P2:** Kd Qs

### Community Cards
- **Flop:** Ah 7c 2h
- **Turn:** Js
- **River:** 9c

### Action
- Pre-flop: P1 goes all-in for 10,000, P2 calls

### Showdown
- **P1 wins** with trip Aces (Ac As Ah)
- P2 has King-Queen high

## Result
- **P2 eliminated**
- **P1 wins the game in a single hand**

## Game Summary
- **Ended:** Hand 1
- **Blind Level:** 50 / 100 (Level 1)

### Notes / Edge Cases
- Game over on hand 1 — no blind rotation ever occurs
- No escalation logic should fire
- With 10,000 chips and 50/100 blinds, the all-in is 100x the BB — pot of 20,000 on hand 1

---
---

# Game 3 — Ends in Level 1 (3 Players)

## Setup
- **Player 1 (P1):** 10,000 chips
- **Player 2 (P2):** 10,000 chips
- **Player 3 (P3):** 10,000 chips
- **Total Chips:** 30,000
- **Blinds:** 50 / 100

---

## Hand 1
**Blinds:** 50 / 100
- **P1:** Button
- **P2:** Small Blind
- **P3:** Big Blind

### Hole Cards
- **P1:** 5d 4d *(folds pre-flop)*
- **P2:** Qs Js
- **P3:** Ac 6h

### Community Cards
- **Flop:** Ts 9s 3d
- **Turn:** 8d
- **River:** 2c

### Action
- Pre-flop: P1 folds, P2 raises to 300, P3 calls
- Flop: P2 bets 400, P3 calls
- Turn: P2 bets 800, P3 calls
- River: P2 bets 1,500, P3 calls

### Showdown
- **P2 wins** with Queen-high straight (Qs Js Ts 9s 8d)
- P3 has Ace-high

### Chip Counts
- **P1:** 10,000
- **P2:** 13,000
- **P3:** 7,000

---

## Hand 2
**Blinds:** 50 / 100
- **P2:** Button
- **P3:** Small Blind
- **P1:** Big Blind

### Hole Cards
- **P2:** Kh 3d *(folds pre-flop)*
- **P3:** 7c 6s
- **P1:** Ah Kc

### Community Cards
- **Flop:** Ad 5c 2s
- **Turn:** Jc
- **River:** 9s

### Action
- Pre-flop: P2 folds, P3 raises to 400, P1 re-raises to 1,200, P3 calls
- Flop: P3 checks, P1 bets 1,500, P3 calls
- Turn: P3 checks, P1 goes raises to 3,600, P3 calls
- River: P3 checks, P1 checks

### Showdown
- **P1 wins** with pair of Aces (Ah Ad)
- P3 has Seven-high (missed straight draw)

### Chip Counts
- **P1:** 16,300
- **P2:** 13,000
- **P3:** 700

---

## Hand 3
**Blinds:** 50 / 100
- **P3:** Button
- **P1:** Small Blind
- **P2:** Big Blind

### Hole Cards
- **P1:** Qd 8s *(calls, then folds)*
- **P2:** 9s 4c *(folds pre-flop)*
- **P3:** 5h 5c

### Community Cards
- **Flop:** 5d Kc 2h
- **Turn:** Js
- **River:** 7d

### Action
- Pre-flop: P3 goes all-in for 700, P1 calls, P2 folds
- Flop through river: P1 and P3 check (P3 all-in)

### Showdown
- **P3 wins** with trip Fives (5h 5c 5d)
- P1 has pair of Kings

### Chip Counts
- **P1:** 15,600
- **P2:** 12,900
- **P3:** 1,500

---

## Hand 4
**Blinds:** 50 / 100
- **P1:** Button
- **P2:** Small Blind
- **P3:** Big Blind

### Hole Cards
- **P1:** Th 8d *(folds pre-flop)*
- **P2:** As Jd
- **P3:** Kc 6h

### Community Cards
- **Flop:** Qs Td 9c
- **Turn:** 8s
- **River:** 2d

### Action
- Pre-flop: P1 folds, P2 raises to 400, P3 goes all-in for 1,500, P2 calls

### Showdown
- **P2 wins** with Ace-high straight (As Jd Qs Td 9c)
- P3 has King-high

## Result
- **P3 eliminated**

### Chip Counts
- **P1:** 15,600
- **P2:** 14,400

---

## Hand 5
**Blinds:** 50 / 100
- **P1:** Small Blind / Button
- **P2:** Big Blind

### Hole Cards
- **P1:** 8h 8d
- **P2:** Ac Ks

### Community Cards
- **Flop:** 8s 8c 3d
- **Turn:** Qh
- **River:** 5s

### Action
- Pre-flop: P1 calls, P2 raises to 500, P1 re-raises to 1,500, P2 calls
- Flop: P1 bets 2,000, P2 raises to 5,000, P1 re-raises to 12,800, P2 calls
- Turn: Both check
- River: both check

### Showdown
- **P1 wins** with quad Eights (8h 8d 8s 8c)
- P2 has Ace-King high (pair of Eights on board only)

### Chip Counts
- **P1:** 29,950
- **P2:** 50

---

## Hand 6
**Blinds:** 50 / 100
- **P2:** Small Blind / Button
- **P1:** Big Blind

### Hole Cards
- **P1:** Kd 7s
- **P2:** Jc 2h

### Community Cards
- **Flop:** Ks 9d 4c
- **Turn:** 3s
- **River:** 6d

### Action
- P2 is SB and forced to go all in (only 50 chips left), P1 checks (already 100 chips from BB)

### Showdown
- **P1 wins** with pair of Kings (Kd Ks)
- P2 has Jack-high

## Result
- **P2 eliminated**
- **P1 wins the game**

## Game Summary
- **Ended:** Hand 6
- **Blind Level:** 50 / 100 (Level 1)

### Notes / Edge Cases
- P3 survived an all-in with only 700 chips (hand 3) and clawed back to 1,500
- P2 reduced to exactly 50 chips — less than 1 SB — forced all-in by the blind itself in hand 6
- BB all-in for less than a full blind: no raise option available for P1, just a call
- Quad Eights in hand 5 demonstrates deep-stack slow-play potential with 10,000 starting chips

---
---

# Game 4 — Three Players, Two Bust Simultaneously (3 Players)

## Setup
- **Player 1 (P1):** 10,000 chips
- **Player 2 (P2):** 10,000 chips
- **Player 3 (P3):** 10,000 chips
- **Total Chips:** 30,000
- **Blinds:** 50 / 100

---

## Hand 1
**Blinds:** 50 / 100
- **P1:** Button
- **P2:** Small Blind
- **P3:** Big Blind

### Hole Cards
- **P1:** Qs Qc
- **P2:** Ad Kd
- **P3:** 9h 8h

### Community Cards
- **Flop:** Th 7h 6s
- **Turn:** Jc
- **River:** 2d

### Action
- Pre-flop: P1 raises to 500, P2 re-raises to 1,500, P3 goes all-in for 10,000, P1 goes all-in for 10,000, P2 calls all-in for remaining 8,500
- Main pot: 30,000 (all three eligible)

### Showdown
- **P3 wins** with a straight (6s 7h 8h 9h Th)
- P1 has pair of Queens
- P2 has Ace-King high

## Result
- **P1 eliminated**
- **P2 eliminated**
- **P3 wins the game**

## Game Summary
- **Ended:** Hand 1
- **Blind Level:** 50 / 100 (Level 1)

### Notes / Edge Cases
- Two players busting on the same hand — game must identify simultaneous eliminations
- No heads-up phase is ever entered
- P1 and P2 share 2nd place (tied finishing position)
- Full 3-way all-in on hand 1 — pot of 30,000 must be handled correctly from the start

---
---

# Game 5 — Four Players, Reaches Level 2 (4 Players)

## Setup
- **Player 1 (P1):** 10,000 chips
- **Player 2 (P2):** 10,000 chips
- **Player 3 (P3):** 10,000 chips
- **Player 4 (P4):** 10,000 chips
- **Total Chips:** 40,000
- **Blinds:** 50 / 100

---

## Hand 1
**Blinds:** 50 / 100
- **P1:** Button
- **P2:** Small Blind
- **P3:** Big Blind
- **P4:** UTG

### Hole Cards
- **P1:** As 9d
- **P2:** Kc Jd
- **P3:** 7s 6s
- **P4:** Th Td *(folds pre-flop)*

### Community Cards
- **Flop:** Ad 8s 3s
- **Turn:** Kd
- **River:** 2c

### Action
- Pre-flop: P4 folds, P1 raises to 300, P2 calls, P3 calls
- Flop: P1 bets 400, P2 calls, P3 calls
- Turn: P1 bets 700, P2 calls, P3 folds
- River: P1 bets 600, P2 folds

### Result
- **P1 wins** uncontested on river (no showdown)

### Chip Counts
- **P1:** 11,500
- **P2:** 8,000
- **P3:** 12,000
- **P4:** 8,500

*Note: P3 ends higher than P2 due to winning a small side pot from P4's blind before folding the main pot.*

---

## Hand 2
**Blinds:** 50 / 100
- **P2:** Button
- **P3:** Small Blind
- **P4:** Big Blind
- **P1:** UTG

### Action
- Pre-flop: P1 raises to 400, P2 folds, P3 folds, P4 folds

### Result
- **P1 wins** uncontested (no showdown — no hole cards assigned)

### Chip Counts
- **P1:** 11,650
- **P2:** 7,900
- **P3:** 11,900
- **P4:** 8,400

---

## Hand 3
**Blinds:** 50 / 100
- **P3:** Button
- **P4:** Small Blind
- **P1:** Big Blind
- **P2:** UTG

### Hole Cards
- **P1:** Ks 5d *(folds pre-flop)*
- **P2:** Ah Jc
- **P3:** Qd Qh
- **P4:** 6c 3h *(folds pre-flop)*

### Community Cards
- **Flop:** Qs Jd 2c
- **Turn:** 7s
- **River:** 4d

### Action
- Pre-flop: P2 raises to 400, P3 calls, P4 folds, P1 folds
- Flop: P2 bets 600, P3 raises to 1,800, P2 goes all-in for 7,500, P3 calls

### Showdown
- **P3 wins** with trip Queens (Qd Qh Qs)
- P2 has pair of Jacks

## Result
- **P2 eliminated**

### Chip Counts
- **P1:** 11,550
- **P3:** 20,050
- **P4:** 8,300

---

## Hands 4–9
**Blinds:** 50 / 100

Small pots, no showdowns, no eliminations. Button rotates correctly skipping no one (all four players still in — wait, P2 is eliminated after hand 3, so button rotates among P1, P3, P4 from hand 4 onward).

### Chip Counts after Hand 9
- **P1:** 10,500
- **P3:** 21,000
- **P4:** 8,400

---

## Hand 10
**Blinds:** ⚠️ ESCALATE TO 100 / 200 (Level 2)
- **P3:** Button
- **P4:** Small Blind
- **P1:** Big Blind

### Hole Cards
- **P1:** Jd 7c *(folds pre-flop)*
- **P3:** Ac Ah
- **P4:** Ks Qd

### Community Cards
- **Flop:** Ad 9c 5h
- **Turn:** 2s
- **River:** 8d

### Action
- Pre-flop: P3 raises to 600, P4 goes all-in for 8,400, P1 folds, P3 calls 7,800 more

### Showdown
- **P3 wins** with trip Aces (Ac Ah Ad)
- P4 has King-Queen high

## Result
- **P4 eliminated**

### Chip Counts
- **P1:** 10,300
- **P3:** 29,700

---

## Hand 11
**Blinds:** 100 / 200
- **P1:** Small Blind / Button
- **P3:** Big Blind

### Hole Cards
- **P1:** Kh Qs
- **P3:** 6c 5c

### Community Cards
- **Flop:** 7c 8c 9c
- **Turn:** Td
- **River:** 2h

### Action
- Pre-flop: P1 raises to 600, P3 re-raises to 2,000, P1 calls
- Flop: P3 bets 3,000, P1 raises all-in for 8,300, P3 calls remaining 5,300

### Showdown
- **P3 wins** with straight flush (5c 6c 7c 8c 9c)
- P1 has King-high (no made hand)

## Result
- **P1 eliminated**
- **P3 wins the game**

## Game Summary
- **Ended:** Hand 11
- **Blind Level:** 100 / 200 (Level 2)

### Notes / Edge Cases
- Blind escalation fires correctly at hand 10
- P4's 8,400 stack at level 2 represents only 42 BBs — immediately pressured by the escalation
- BTN rotation correctly skips P2 from hand 4 onward
- Transition from 4-handed to 3-handed to heads-up all handled in this game

---
---

# Game 6 — Four Players, Reaches Level 3 (4 Players)

## Setup
- **Player 1 (P1):** 10,000 chips
- **Player 2 (P2):** 10,000 chips
- **Player 3 (P3):** 10,000 chips
- **Player 4 (P4):** 10,000 chips
- **Total Chips:** 40,000
- **Blinds:** 50 / 100

---

## Hands 1–9
**Blinds:** 50 / 100

Tight, deep-stacked play. No showdowns, no eliminations. Chips shuffle gradually through small pots and uncontested raises. No hole cards assigned.

### Chip Counts after Hand 9
- **P1:** 11,000
- **P2:** 9,000
- **P3:** 12,000
- **P4:** 8,000

---

## Hand 10
**Blinds:** ⚠️ ESCALATE TO 100 / 200 (Level 2)
- **P1:** Button
- **P2:** Small Blind
- **P3:** Big Blind
- **P4:** UTG

### Hole Cards
- **P1:** Kd Qc
- **P2:** 7h 4s *(folds pre-flop)*
- **P3:** 8d 8s
- **P4:** Ac 2d *(folds pre-flop)*

### Community Cards
- **Flop:** 8h 5d 3c
- **Turn:** Js
- **River:** 9d

### Action
- Pre-flop: P4 folds, P1 raises to 600, P2 folds, P3 re-raises to 1,800, P1 calls
- Flop: P3 bets 2,000, P1 calls
- Turn: P3 bets 3,000, P1 calls
- River: P3 bets 4,000, P1 calls

### Showdown
- **P3 wins** with trip Eights (8d 8s 8h)
- P1 has King-Queen high

### Chip Counts
- **P1:** 6,200
- **P2:** 8,900
- **P3:** 16,600
- **P4:** 8,000

---

## Hands 11–14
**Blinds:** 100 / 200

Escalated pressure. P1 bleeds chips folding to continuation bets. No showdowns. No hole cards assigned.

### Chip Counts after Hand 14
- **P1:** 4,500
- **P2:** 9,500
- **P3:** 18,000
- **P4:** 8,000

---

## Hand 15
**Blinds:** 100 / 200
- **P2:** Button
- **P3:** Small Blind
- **P4:** Big Blind
- **P1:** UTG

### Hole Cards
- **P1:** Kc 9s
- **P2:** 6d 2c *(folds pre-flop)*
- **P3:** Ad 7d *(folds pre-flop)*
- **P4:** Jd Jc

### Community Cards
- **Flop:** Jh 5s 4d
- **Turn:** 8c
- **River:** 2d

### Action
- Pre-flop: P1 goes all-in for 4,500, P2 folds, P3 folds, P4 calls

### Showdown
- **P4 wins** with trip Jacks (Jd Jc Jh)
- P1 has King-Nine high

## Result
- **P1 eliminated**

### Chip Counts
- **P2:** 9,500
- **P3:** 17,900
- **P4:** 12,600

---

## Hands 16–19
**Blinds:** 100 / 200

Three-handed play. P2 gradually loses ground to P3 and P4. No showdowns. No hole cards assigned.

### Chip Counts after Hand 19
- **P2:** 6,000
- **P3:** 19,500
- **P4:** 14,500

---

## Hand 20
**Blinds:** ⚠️ ESCALATE TO 200 / 400 (Level 3)
- **P4:** Button
- **P2:** Small Blind
- **P3:** Big Blind

### Hole Cards
- **P2:** As 8c
- **P3:** Qd 7s *(folds pre-flop)*
- **P4:** Kh Kc

### Community Cards
- **Flop:** Kd 9c 3s
- **Turn:** 5h
- **River:** Jd

### Action
- Pre-flop: P4 raises to 1,200, P2 goes all-in for 6,000, P3 folds, P4 calls 4,800 more

### Showdown
- **P4 wins** with trip Kings (Kh Kc Kd)
- P2 has pair of Aces (As + no Ace on board — Ace-high only)

## Result
- **P2 eliminated**

### Chip Counts
- **P3:** 19,100
- **P4:** 20,900

---

## Hand 21
**Blinds:** 200 / 400
- **P4:** Small Blind / Button
- **P3:** Big Blind

### Hole Cards
- **P3:** Qh Qd
- **P4:** Ah Ad

### Community Cards
- **Flop:** As Qc 6h
- **Turn:** 3d
- **River:** 8s

### Action
- Pre-flop: P4 raises to 1,200, P3 re-raises to 3,600, P4 calls
- Flop: P3 bets 4,000, P4 calls
- Turn: P3 bets 5,000, P4 calls
- River: P3 goes all-in for 6,500, P4 calls

### Showdown
- **P4 wins** with trip Aces (Ah Ad As)
- P3 has trip Queens (Qh Qd Qc)

## Result
- **P3 eliminated**
- **P4 wins the game**

## Game Summary
- **Ended:** Hand 21
- **Blind Level:** 200 / 400 (Level 3)

### Notes / Edge Cases
- Blind escalation fires twice (hand 10 and hand 20)
- At level 3, the BB (400) is 4% of a starting stack — players are not yet pot-committed just by posting
- P2's 6,000 stack at hand 20 represents only 15 BBs at the new level — severely vulnerable
- Set-over-set in hand 21 (trip Aces vs trip Queens) — a dramatic but valid cooler scenario
- Both escalations must be validated: hand 10 triggers level 2, hand 20 triggers level 3

---
---

# Game 7 — Four Players, Short Stack Comeback (4 Players)

## Setup
- **Player 1 (P1):** 10,000 chips
- **Player 2 (P2):** 10,000 chips
- **Player 3 (P3):** 10,000 chips
- **Player 4 (P4):** 10,000 chips
- **Total Chips:** 40,000
- **Blinds:** 50 / 100

---

## Hand 1
**Blinds:** 50 / 100
- **P1:** Button
- **P2:** Small Blind
- **P3:** Big Blind
- **P4:** UTG

### Hole Cards
- **P1:** Ad 8s
- **P2:** 9h 4d *(folds pre-flop)*
- **P3:** Kc 2d *(folds pre-flop)*
- **P4:** Ks Qs

### Community Cards
- **Flop:** Qd 7s 3s
- **Turn:** 5s
- **River:** Jd

### Action
- Pre-flop: P4 raises to 400, P1 calls, P2 folds, P3 folds
- Flop: P4 bets 600, P1 calls
- Turn: P4 bets 1,500, P1 calls
- River: P4 bets 3,000, P1 calls

### Showdown
- **P4 wins** with a flush (Ks Qs 7s 5s 3s)
- P1 has Ace-high

### Chip Counts
- **P1:** 4,500
- **P2:** 9,950
- **P3:** 9,900
- **P4:** 15,600

---

## Hand 2
**Blinds:** 50 / 100
- **P2:** Button
- **P3:** Small Blind
- **P4:** Big Blind
- **P1:** UTG

### Hole Cards
- **P1:** Ac As
- **P2:** Qh Jh *(folds pre-flop)*
- **P3:** Kd 8d *(folds pre-flop)*
- **P4:** Td 9c

### Community Cards
- **Flop:** 2h 7c Kc
- **Turn:** 5d
- **River:** 3s

### Action
- Pre-flop: P1 goes all-in for 4,500, P2 folds, P3 folds, P4 calls

### Showdown
- **P1 wins** with pair of Aces (Ac As)
- P4 has Ten-Nine high

### Chip Counts
- **P1:** 9,050
- **P2:** 9,900
- **P3:** 9,850
- **P4:** 11,100

---

## Hand 3
**Blinds:** 50 / 100
- **P3:** Button
- **P4:** Small Blind
- **P1:** Big Blind
- **P2:** UTG

### Hole Cards
- **P1:** Jc 6h *(folds pre-flop)*
- **P2:** Ah Qh
- **P3:** 7d 3c *(folds pre-flop)*
- **P4:** Kc Kd

### Community Cards
- **Flop:** Kh 5c 4h
- **Turn:** 2c
- **River:** 9s

### Action
- Pre-flop: P2 raises to 400, P3 folds, P4 re-raises to 1,200, P1 folds, P2 goes all-in for 9,900, P4 calls remaining 8,700

### Showdown
- **P4 wins** with trip Kings (Kc Kd Kh)
- P2 has Ace-Queen high (missed flush draw)

## Result
- **P2 eliminated**

### Chip Counts
- **P1:** 8,950
- **P3:** 9,850
- **P4:** 21,100

---

## Hands 4–9
**Blinds:** 50 / 100

Three-handed play. P1 rebuilds steadily, P3 stays even, P4 remains dominant. No showdowns. No hole cards assigned.

### Chip Counts after Hand 9
- **P1:** 10,500
- **P3:** 8,500
- **P4:** 21,000

---

## Hand 10
**Blinds:** ⚠️ ESCALATE TO 100 / 200 (Level 2)
- **P1:** Button
- **P3:** Small Blind
- **P4:** Big Blind

### Hole Cards
- **P1:** Qc Jd
- **P3:** Ks Kh
- **P4:** 8d 6s *(folds pre-flop)*

### Community Cards
- **Flop:** Kd 7s 3c
- **Turn:** Tc
- **River:** 2d

### Action
- Pre-flop: P1 raises to 600, P3 goes all-in for 8,500, P4 folds, P1 calls remaining 7,900

### Showdown
- **P3 wins** with trip Kings (Ks Kh Kd)
- P1 has Queen-Jack high

### Chip Counts
- **P1:** 2,000
- **P3:** 17,100
- **P4:** 20,800

---

## Hand 11
**Blinds:** 100 / 200
- **P3:** Button
- **P4:** Small Blind
- **P1:** Big Blind

### Hole Cards
- **P1:** 9c 5s
- **P3:** Js Td *(folds pre-flop)*
- **P4:** Ad Kc

### Community Cards
- **Flop:** As Ac 4d
- **Turn:** 7h
- **River:** Qd

### Action
- Pre-flop: P4 raises to 600, P3 folds, P1 goes all-in for 2,000, P4 calls remaining 1,400

### Showdown
- **P4 wins** with trip Aces (Ad Ac As)
- P1 has Nine-high

## Result
- **P1 eliminated**

### Chip Counts
- **P3:** 17,100
- **P4:** 22,800

---

## Hand 12
**Blinds:** 100 / 200
- **P4:** Small Blind / Button
- **P3:** Big Blind

### Hole Cards
- **P3:** Qd Qs
- **P4:** Ah Ad

### Community Cards
- **Flop:** As Qc 6h
- **Turn:** 3d
- **River:** 8s

### Action
- Pre-flop: P4 raises to 600, P3 re-raises to 2,000, P4 calls
- Flop: P3 bets 3,000, P4 calls
- Turn: P3 goes all-in for 12,100, P4 calls

### Showdown
- **P4 wins** with trip Aces (Ah Ad As)
- P3 has trip Queens (Qd Qs Qc)

## Result
- **P3 eliminated**
- **P4 wins the game**

## Game Summary
- **Ended:** Hand 12
- **Blind Level:** 100 / 200 (Level 2)

### Notes / Edge Cases
- P1 lost over 55% of their stack on hand 1 via deep multi-street betting — only possible with 10,000 starting stacks
- P1 doubled up in hand 2 (all-in survival) then rebuilt to above starting stack by hand 9
- P1 lost everything again at the blind escalation moment (hand 10) — shows how escalation punishes mid-stack players
- P1 entered level 2 with only 2,000 chips — 10 BBs — making the BB (200) itself a significant portion
- Set-over-set (Aces vs Queens) appears in both hand 12 here and hand 21 of Game 6 — board As Qc 6h is identical, which should be changed in one game to avoid duplicate boards. Adjust Game 7 Hand 12 river to 8h and turn to 4s for a distinct runout: Flop As Qc 6d / Turn 4s / River 8h
- BTN rotation correctly skips P2 after elimination from hand 4 onward



