# APS Reader visual spec (derived from supplied references)

Sources: (1) gateway statistics screenshot: white rounded card, 1px #E5E7EB border, gateway logo in 40px circle left, bold name, status pill right
(green #E3F5EA/#1E8E4E "Connected", salmon #FCE4DC/#C2410C "Not Connected"), label/value rows, hairline dividers.
(2) bank history reference: pale #F5F8FC page bg, day group headers ("Today", "Yesterday") small bold #1F3A5F, rows: circular colored icon with status badge,
title + "№ id" subtitle, right-aligned amount (green positive), segmented summary chips at top, bottom sheet filters (Period/Apply/Reset), search sheet.
(3) FinQ: bottom nav with rounded pill highlight on the active tab (icon + label), others icon only; section headers w/ "See all".
(4) APS logo: royal blue (#2B5BD7 approx) wordmark on light blue.

Tokens: primary #2B5BD7, primaryDark #1E3FA0, ink #0F1B33, muted #667085, bg #F5F8FC, card #FFFFFF, border #E5E7EB,
success #1E8E4E / bg #E3F5EA, warn #B54708 / bg #FEF0C7, danger #B42318 / bg #FEE4E2, info bg #E8EEFF.
Radius: card 16, chip 999, button 14, input 14. Page padding 16. Card padding 14-16. Font: Roboto (system), title 20/700, section 16/700, body 14, caption 12.
Bottom nav: 5 items (Dashboard, Transactions, Alerts, Gateways, Settings), height 68, active item = pill #E8EEFF with blue icon+label.
Icons: Material Symbols rounded via Icons.*_rounded. Gateway logos from assets/images (bkash.png, nagad.png, rocket_full.png) + Upay drawn as brand-colored "U" badge until official logo supplied.
