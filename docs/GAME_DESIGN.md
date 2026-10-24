# Game design: Borrowed Luck (working title)

Game jam theme: **TRICK**. Gambling roguelike. You borrow chips from collectors and play casino games on
them. Each game has its own pool of artifacts (tricks). Few are open at first; the rest unlock by what
the player does (die, land a blackjack, cheat, go all-in...).

## Decisions made with the author

| Topic | Decision |
|---|---|
| Platform | PC and phone at once, landscape. 2D UI base 640x360 (`canvas_items` + `expand`); the 3D view renders at the real resolution |
| First slice | Blackjack only. The code is built so that every game is a module with its own artifact pool |
| Run | Endless until death, goal is a record (payments survived, then peak chips) |
| Debt | The house lends 150 chips and writes a debt of 250 at once. The stake is always all in: a win doubles the purse, a loss is a death unless it leaves more than the loan (an artifact gave chips back). Due after 4 hands, payable early. Paying brings the next loan (x2: 300, 600...) and a debt that grows faster (x2.5: 625, 1565...), so the wins in a row it takes climb from 1 to 3 and beyond; a free artifact offer opens. Measured with `tools/balance.gd`: about 2.6 debts and 10 hands per run for a bot without artifacts. Cannot pay = a death. A death costs a finger and the loan is lent again on top of the chips that are left |
| Death | A death costs a finger of the right hand (5 lives): the house lends the current loan again. The fifth ends the run; meta progress (unlocks, stats) stays |
| Artifacts | 3 slots. A run starts empty: a free offer of 3 random unlocked artifacts, pick one. Another free offer only when a loan is paid off. Replace or discard when full. Four kinds, each its own colour: active blue, passive green, consumable amber, cursed crimson |
| Deadline | Five candles on the far rail, one snuffed per hand; the installment due floats beside them. Redder light and two enforcers leaning in as it nears; on the last hand a hand raps three times on the felt; three knocks when it falls |
| Feedback | A triggered artifact pops into the middle of the screen, shaking, and leaves the same way. A newly opened one slides in at the bottom-right with its icon and the reason it opened |
| Unlocks | Deaths (first, third, by debt), risky acts (double down win, all-in), doubtful acts (using tricks), wealth and streaks, a natural blackjack |
| Dealer | Faceless croupier with short ominous lines |
| Rules | Hit, Stand (Double only if chips are left, which all in rarely allows). Blackjack pays 3:2, dealer stands on 17. No split or insurance in the slice |
| Language | English and Russian from the start (`tr()` with `i18n/strings.json`) |
| Tone | Dark, oppressive, modern: an abandoned underground casino, not a medieval dungeon (see `assets/README.md`) |
| View | 3D, first person at the table, stylized low-poly with soft light. Menus stay 2D pixel UI |
| Controls | Everything pressable is an object on the table: plaques and the artifacts in the left hand. Chips are only a display. Numbers and subtitles are a 2D overlay |
| Table layout | Table across the view, dealer opposite. Chips standing in columns by denomination on a rack along the near rim (display only), action buttons in a row above it, bet circle in the middle. Artifacts are wedged like coins between the fingers of the player's left hand (the coin roll grip), which lies on the table; the hovered one rolls out and spins to show its emblem. The right hand lies on the table too and does every press |
| Buttons | 3D but camera-aligned (never skewed), large, with hover ring, press squash and a shake when unavailable |

## Run loop

1. Menu: take a seat. The house lends 150 chips and writes a debt of 250.
2. At the table the free offer opens: pick 1 of up to 3 random unlocked artifacts (or skip).
3. Hands: deal (always all in), play, resolve. Artifacts hook in at fixed points (see ARCHITECTURE in `CLAUDE.md`).
4. Reach the debt in chips and pay it, early with the button or on the deadline (`PAYMENT_EVERY` = 4 hands).
5. A paid debt: the next loan (double) arrives, a bigger debt is written (x5 of the loan), a free artifact offer opens.
6. Cannot pay the debt, or a lost hand that leaves less than the loan: death (a finger; the loan is added to what is left). The result screen shows the record and every new unlock. The menu's Collection shows every artifact; a closed one only says Locked.

## What is in the game (the hooks artifacts can use)

| System | What exists | Hooks / API |
|---|---|---|
| The hand | Hit, Stand, (Double only with chips left), natural blackjack 3:2, dealer stands on 17, a 6-deck shoe | `hand_started`, `hand_dealt`, `prevent_bust`, `modify_payout`, `can_use` / `use` |
| The stake | Always the whole purse (all in) | `modify_stake` |
| The shoe and cards | Hole card, next card, undo returns a card on top, swap buries it | `peek_hole`, `peek_next_card`, `discard_last_player_card`, `redeal_player_hand`, `freeze_dealer` |
| The debt | Loan and debt written at once, both exponential, a deadline in hands, early payoff | `modify_payment`, `modify_deadline`, `modify_new_loan`, `modify_new_debt`, `reduce_debt`, `extend_deadline` |
| Lives | Five fingers; a death lends the current loan again | `prevent_death` |
| Offers | A free pick of three after every debt paid | none (artifacts are what is offered) |
| Counters | hands played / won, blackjacks, busts, deaths, debt deaths, chips peak, win streak, tricks used, debts paid | unlock rules (`unlock_stat`, `unlock_value`) |
| Buttons | A cooldown in hands, charges for consumables, a spent consumable leaves the slot | `cooldown_hands`, `charges` |

## Artifact matrix: kind x system

Each cell is one artifact; an empty cell is room for the next one.

| System | Active (button, cooldown) | Passive (always on) | Consumable (charges, then gone) | Cursed (a price) |
|---|---|---|---|---|
| Hand and cards | Card Sleeve (swap a card, 3 hands), Cracked Mirror (next card, 3 hands), Stacked Deck (bury the next card, 3 hands) | Marked Deck (hole card), Glass Eye (next card each hand), Gambler's Nerve (4+ cards) | Lucky Clover (undo a bust), Top Hat (ace), Second Wind (redeal), Sleeping Powder (dealer stands) | |
| Payout | | Sleight of Hand (blackjack 2:1), Rabbit's Foot (streaks), Lucky Penny (pushes), Steady Hands (doubles), Pauper's Crown (small winning hands) | | Cursed Doll (+50% wins, pushes lose), Black Cat (19+ pay double, 17- only the stake) |
| The stake | | Loose Change (half a lost stake back, every 5 hands) | | |
| The debt | | Silver Chip (-10% due), Pawn Ticket (new debts -10%) | Hush Envelope (-25% now) | Collector's Ledger (-15% due, a hand sooner), Fat Purse (+50% loans, +50% debts) |
| The deadline | | | Hourglass (+2 hands) | Collector's Ledger, Borrowed Time (+2 hands, smaller loans) |
| Lives | | | Candle of Mercy (survive a death, the last loan again), Pawned Finger (a finger for the whole debt) | |

Ideas for the empty cells: an active that trades a finger for a win, a passive that grows the loan with the win streak, a cursed
artifact that shortens the deadline for bigger payouts.

## Artifact kinds

- **Active**: a button; limited uses per hand. Some trick costs "hush money".
- **Passive**: always on, modifies payouts, payments or rules.
- **Consumable**: a fixed number of charges per run, spent for good.
- **Cursed**: a strong effect with a price attached.

## Blackjack artifact pool

| Id | Kind | Effect | Unlock |
|---|---|---|---|
| lucky_clover | consumable, 3 | Undo a bust: the last card goes back on top of the shoe and lies face up beside it, as with the Cracked Mirror | open |
| marked_deck | passive | Every hand starts with the dealer's hole card shown | use the Cracked Mirror 10 times |
| card_sleeve | active, 3 hands | Swap your last card for a fresh one, costs 15% of the stake | open |
| cracked_mirror | active, 3 hands | Show the next card of the shoe | win 3 hands |
| cursed_doll | cursed | Wins pay +50%, a push counts as a loss | open |
| black_cat | cursed | 19+ wins pay double, wins on 17 or less only return the stake | win 4 in a row |
| silver_chip | passive | The debt due is 10% smaller | open |
| sleight_of_hand | passive | A natural blackjack pays 2:1 | land a natural blackjack |
| lucky_penny | passive | A push pays half a stake more | the first push |
| gamblers_nerve | passive | Winning with 4+ cards pays +50% | win 12 hands |
| rabbits_foot | passive | Wins in a streak of 2+ pay +10% per streak step | win 3 in a row |
| loose_change | passive | A lost hand gives half the stake back; works once every 5 hands | die twice |
| pawn_ticket | passive | New debts are written 10% smaller | pay 4 debts |
| fat_purse | cursed | New loans +50%, new debts +50% | hold 1500 chips |
| collectors_ledger | cursed | The debt due is 15% smaller, the deadline a hand sooner | die to the collectors |
| candle_of_mercy | consumable, 1 | Survive a death, the house hands over your last loan again | die 3 times |
| top_hat | consumable, 1 | Turn your last card into an Ace | use tricks 10 times |
| second_wind | consumable, 1 | Throw your hand away and deal two new cards | hold 600 chips |
| sleeping_powder | consumable, 2 | The dealer stands on whatever he has | bust 4 times |
| hourglass | consumable, 2 | +2 hands before the debt falls due, also between hands | pay 2 debts |
| hush_envelope | consumable, 1 | Cut the debt by a quarter, also between hands | die to the collectors |
| stacked_deck | active, 3 hands | Bury the next card at the bottom of the shoe and show the one beneath | make the dealer bust 6 times |
| glass_eye | passive, rare | Every hand starts with the next card of the shoe shown beside it | see the shoe shuffled 3 times |
| steady_hands | passive | A won double down pays half a stake more | win 6 hands in a row |
| borrowed_time | cursed | Two more hands before a debt falls due, new loans a tenth smaller | die to the collectors 3 times |
| sore_loser | passive | After a lost hand the next one starts with a ten | die 4 times |
| credit_line | passive, rare | Double down with an empty purse; the borrowed chips are added to the debt | the dealer draws a blackjack |
| magpie | passive | A free offer shows one artifact more | pay 6 debts |
| shaky_hand | passive | The dealer stands on 16 instead of 17 | win 20 hands |
| three_cherries | passive | A won 21 of three or more cards pays a stake more | play 40 hands |
| rematch | passive, rare | A push changes the dealer's last card for a new one and he plays on; recharge 3 hands | push with 21 against 21 |
| card_fan | active, 3 hands | Lays out the next three cards: take one, the other two go to the bottom | two sevens as the first two cards |
| traitors_chip | active, rare, 3 hands | Between hands: bet on the dealer (a lost hand pays 1:1, a bust 2:1, a win is a loss) | close a debt with less than 10 chips left |
| card_counter | passive | Shows the Hi-Lo count of the cards seen since the shuffle beside the shoe | play 100 hands |
| pickpocket | active, 4 hands | Takes the dealer's open card into your hand, he gets a fresh one | pay a debt the moment it is received |
| hand_swap | active, rare, 6 hands | You and the dealer swap hands, his hidden card turns face up | hold three artifacts of one kind |
| pawned_finger | consumable, 1 | Between hands: lose a finger, the purse is topped up and the whole debt is paid at once (not the last finger) | die to the collectors twice |
| encore | passive, rare | Once per loan a trick that was just used is given back, so it can be repeated at once | use tricks 40 times |
| paupers_crown | passive, rare | A won hand of 15 or less pays a whole stake more | win a hand with 10 or less (the dealer busts) |

The one unlock that depends on another artifact is Marked Deck (10 uses of the Cracked Mirror); every other artifact opens on its own kind of event (pushes, dealer busts, shuffles, doubles, deaths, a win with 10 or less...), so no two unlock the same way. Open from the start: Lucky Clover, Card Sleeve, Cursed Doll, Silver Chip.

Numbers live in `core/rules.gd` and in each artifact `.tres`; this table is a retelling.

## Mechanics map: what is taken and what is still free

Every artifact touches one mechanic through a hook. A mechanic that already has an artifact is not used a second time with
the same idea; a free one is room for the next artifact.

| Mechanic (hook) | Taken by | Still free |
|---|---|---|
| Cards seen: the hole card (`peek_hole`), the next card (`peek_next_card`) | Marked Deck, Cracked Mirror, Glass Eye, Lucky Clover (shows the undone card) | peeking at the dealer's next draw; the order of the next three |
| Cards changed: swap, undo, bury, redeal, an ace (`replace_last_player_card`, `discard_last_player_card`, `bury_next_card`, `redeal_player_hand`, `last_player_card_becomes_ace`) | Card Sleeve, Lucky Clover, Stacked Deck, Second Wind, Top Hat | stealing a dealer's card; a wild card; splitting |
| Cards given: a ten slipped on top of the shoe (`hand_started`) | Sore Loser | an ace after a blackjack; a pair on demand |
| The dealer's play: freeze, stand on a total (`freeze_dealer`, `modify_dealer_stands_on`) | Sleeping Powder, Shaky Hand | the dealer busts on 22+; a dealer who shows both cards |
| The payout by hand: win, push, loss (`modify_payout`) | Sleight of Hand (blackjack), Lucky Penny (push), Cursed Doll (wins, pushes), Black Cat (19+), Gambler's Nerve (4+ cards), Steady Hands (doubles), Pauper's Crown (15 or less), Three Cherries (21 of 3+ cards), Loose Change (loss refund), Rabbit's Foot (streak) | a payout by the dealer's total; by the card suits; by a first card |
| The stake (`modify_stake`) | nothing | a capped stake that keeps the rest safe (the old Loose Change); a bigger first hand |
| Double down (`allows_credit_double`) | Credit Line | doubling after a hit; doubling for free once per loan |
| The debt: payment, new debt, new loan, deadline (`modify_payment`, `modify_new_debt`, `modify_new_loan`, `modify_deadline`, `reduce_debt`, `extend_deadline`) | Silver Chip, Pawn Ticket, Fat Purse, Borrowed Time, Collector's Ledger, Hourglass, Hush Envelope | the debt growing with the win streak; paying early with a bonus; a lender who forgets a hand |
| Lives (`prevent_death`, `pawn_finger`) | Candle of Mercy, Pawned Finger | an extra finger; healing a finger; a finger traded for chips outside a debt |
| Offers (`modify_offer_size`) | Magpie | rerolling an offer; a guaranteed rare; selling a held artifact |
| After a hand (`hand_ended`) | Sore Loser | momentum after a win; a reshuffle after a loss |
| Unlock events | hands played / won, busts, deaths (all, by debt), chips peak, win streak, tricks, debts paid, blackjacks, pushes, wins with 10 or less, dealer busts, shoe shuffles, doubles, dealer blackjacks, Cracked Mirror uses | an early payoff; a fifth-finger run; surviving with fewer than ten chips |

## The pocket

Artifacts can be stored in the pocket (2 wells) between hands; stored ones do not work. Deeper Pocket (consumable, opens at 20 hands) adds a well for the run; Smuggler's Backpack (passive, opens by using the Deeper Pocket) adds two while worn or stored; Clenched Fist (cursed, opens after 5 hands in the Backpack) takes one away and pays half as much again on a win.

## Artifact balance (tools/artifact_balance.gd)

A bot with basic strategy holds one artifact from the start; debts closed per run is compared with a run of nothing (about 2.5). It pays debts early, so deadline changes and anything that needs a human's judgement (mirror, clover, hourglass, hand swap, counter) read as zero: those are tuned by feel. Tuned after the first sweep: Collector's Ledger (+0.9, now -15% due), Pawn Ticket, Loose Change (+0.5, now every 5 hands), Fat Purse (-0.3, now +50% debts, about +0.1), Borrowed Time (-0.6, now -10% loans), Card Sleeve and Pickpocket (weak, cheaper). Clenched Fist (x1.5 on a win, +0.7) was left at the number asked for: it is the strongest artifact in the pool by design, and a cursed one.
