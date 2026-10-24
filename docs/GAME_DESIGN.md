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
| Debt | The house lends 150 chips and writes a debt of 250 at once. The stake is always all in: a win doubles the purse, a loss is a death. Due after 4 hands, payable early. Paying brings the next loan (x2: 300, 600...) and a debt that grows faster (x2.5: 625, 1565...), so the wins in a row it takes climb from 1 to 3 and beyond; a free artifact offer opens. Measured with `tools/balance.gd`: about 2.6 debts and 10 hands per run for a bot without artifacts. Cannot pay = a death |
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
6. Cannot pay the debt or out of chips: death. The result screen shows the record and every new unlock. The menu's Collection shows every artifact and how to unlock the closed ones.

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
| Hand and cards | Card Sleeve (swap a card, 3 hands), Cracked Mirror (next card, 3 hands) | Marked Deck (hole card), Gambler's Nerve (4+ cards) | Lucky Clover (undo a bust), Top Hat (ace), Second Wind (redeal), Sleeping Powder (dealer stands) | |
| Payout | | Sleight of Hand (blackjack 2:1), Rabbit's Foot (streaks), Lucky Penny (pushes) | | Cursed Doll (+50% wins, pushes lose), Black Cat (19+ pay double, 17- only the stake) |
| The stake | | Loose Change (keep a quarter) | | |
| The debt | | Silver Chip (-10% due), Pawn Ticket (new debts -15%) | Hush Envelope (-25% now) | Collector's Ledger (-30% due, a hand sooner), Fat Purse (+50% loans, +75% debts) |
| The deadline | | | Hourglass (+2 hands) | Collector's Ledger |
| Lives | | | Candle of Mercy (survive a death, the last loan again) | |

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
| card_sleeve | active, 3 hands | Swap your last card for a fresh one, costs 20% of the stake | win 5 hands |
| cracked_mirror | active, 3 hands | Show the next card of the shoe | win 3 hands |
| cursed_doll | cursed | Wins pay +50%, a push counts as a loss | die once |
| black_cat | cursed | 19+ wins pay double, wins on 17 or less only return the stake | win 4 in a row |
| silver_chip | passive | The debt due is 10% smaller | hold 1000 chips |
| sleight_of_hand | passive | A natural blackjack pays 2:1 | land a natural blackjack |
| lucky_penny | passive | A push pays half a stake more | play 15 hands |
| gamblers_nerve | passive | Winning with 4+ cards pays +50% | win 12 hands |
| rabbits_foot | passive | Wins in a streak of 2+ pay +10% per streak step | win 3 in a row |
| loose_change | passive | A quarter of the purse stays out of the stake | die twice |
| pawn_ticket | passive | New debts are written 15% smaller | pay 4 debts |
| fat_purse | cursed | New loans +50%, new debts +75% | hold 1500 chips |
| collectors_ledger | cursed | The debt due is 30% smaller, the deadline a hand sooner | die to the collectors |
| candle_of_mercy | consumable, 1 | Survive a death, the house hands over your last loan again | die 3 times |
| top_hat | consumable, 1 | Turn your last card into an Ace | use tricks 10 times |
| second_wind | consumable, 1 | Throw your hand away and deal two new cards | hold 600 chips |
| sleeping_powder | consumable, 2 | The dealer stands on whatever he has | bust 4 times |
| hourglass | consumable, 2 | +2 hands before the debt falls due, also between hands | pay 2 debts |
| hush_envelope | consumable, 1 | Cut the debt by a quarter, also between hands | die to the collectors |

Numbers live in `core/rules.gd` and in each artifact `.tres`; this table is a retelling.
