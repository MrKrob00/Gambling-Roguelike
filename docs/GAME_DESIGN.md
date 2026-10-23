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
| Debt | A payment is taken every 5 hands and each one is bigger. Not enough chips = death |
| Death | All chips are lost, the run ends, meta progress (unlocks, stats) stays |
| Artifacts | 3 slots. A run starts empty: a free offer of 3 random unlocked artifacts, pick one. After every payment a paid offer for 30% of the next payment. Replace or discard when full. Four kinds, each its own colour: active blue, passive green, consumable amber, cursed crimson |
| Deadline | Five candles on the far rail, one snuffed per hand; the amount due floats beside them. Redder light, heartbeat on the last hand, three knocks when it falls |
| Unlocks | Deaths (first, third, by debt), risky acts (double down win, all-in), doubtful acts (using tricks), wealth and streaks, a natural blackjack |
| Dealer | Faceless croupier with short ominous lines |
| Rules | Hit, Stand, Double. Blackjack pays 3:2, dealer stands on 17. No split or insurance in the slice |
| Language | English and Russian from the start (`tr()` with `i18n/strings.json`) |
| Tone | Dark, oppressive, modern: an abandoned underground casino, not a medieval dungeon (see `assets/README.md`) |
| View | 3D, first person at the table, stylized low-poly with soft light. Menus stay 2D pixel UI |
| Controls | Everything pressable is an object on the table: chip piles, plaques, artifact tokens. Numbers and subtitles are a 2D overlay |
| Table layout | Table across the view, dealer opposite. Artifacts on a tray at the left, chip piles on a plate at the right, bet circle in the middle, action buttons in one row at the near edge |
| Buttons | 3D but camera-aligned (never skewed), large, with hover ring, press squash and a shake when unavailable |

## Run loop

1. Menu: take a seat. The collectors lend `START_CHIPS` and the first payment is announced.
2. At the table the free offer opens: pick 1 of up to 3 random unlocked artifacts (or skip).
3. Hands: bet, deal, play, resolve. Artifacts hook in at fixed points (see ARCHITECTURE in `CLAUDE.md`).
4. Every `PAYMENT_EVERY` hands the payment is due. Paid from chips; `PAYMENT_GROWTH` makes the next bigger.
5. After each payment the house sells a new choice of artifacts for a share of the next payment.
6. Cannot pay or out of chips: death. The result screen shows the record and every new unlock. The menu's Collection shows every artifact and how to unlock the closed ones.

## Artifact kinds

- **Active**: a button; limited uses per hand. Some trick costs "hush money".
- **Passive**: always on, modifies payouts, payments or rules.
- **Consumable**: a fixed number of charges per run, spent for good.
- **Cursed**: a strong effect with a price attached.

## Blackjack artifact pool (slice)

| Id | Kind | Effect | Unlock |
|---|---|---|---|
| lucky_clover | consumable, 3 | Undo a bust: the last card is discarded | open |
| marked_deck | active | Peek at the dealer's hole card, once per hand | open |
| card_sleeve | active | Swap your last card for a fresh one, costs 25% of the bet | win 5 hands |
| cursed_doll | cursed | Wins pay +25%, losses cost +25% | die once |
| silver_chip | passive | Payments are 10% smaller | hold 1000 chips |
| sleight_of_hand | passive | A natural blackjack pays 2:1 | land a natural blackjack |
| candle_of_mercy | consumable, 1 | Survive a failed payment with 50 chips | die 3 times |
| gamblers_nerve | passive | Winning after a double down pays +50% | win a doubled hand |
| collectors_ledger | cursed | Payments are 30% smaller, the minimum bet is 25 | die to the collectors |
| rabbits_foot | passive | Wins in a streak of 2+ pay +10% per streak step | win 3 in a row |
| top_hat | consumable, 1 | Turn your last card into an Ace | use tricks 10 times |

Numbers live in `core/rules.gd` and in each artifact `.tres`; this table is a retelling.
