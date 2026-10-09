# Caticus Rebuilt Menu

This is now open source to allow you to edit, add new things as you please. Rebuilt fully and 100% rewrote by myself

## Features

### Overview Dashboard
- Economy Health Score (0-100) based on flow balance, wealth distribution, velocity, player activity
- Server totals for cash, bank, dirty money, crypto
- Live faucet/sink tracking with net flow
- 30-day money flow charts
- Wealth distribution breakdown
- Week-over-week comparison

### Faucets & Sinks
- Category breakdown showing where money enters/exits
- Filter by category and date range
- Pie charts for quick analysis
- Transaction counts and averages

### Analytics
- Gini coefficient for wealth inequality
- Wealth percentiles (top 1%, 10%, 50%)
- Wealth brackets from Broke to Ultra Rich
- Leaderboards for richest, top earners, top spenders

### Inflation Tracking
- Consumer Price Index (CPI) monitoring
- Auto price logging via exports
- Manual price updates
- Price change history

### Player Management
- Search by name or citizen ID
- Player profiles with earnings, spending, history
- Live balance display

### Alerts
- Configurable triggers for rapid wealth gain, large transactions, inflation spikes
- Severity levels (low, medium, high, critical)
- Status tracking (new, reviewed, resolved, dismissed)
- Discord notifications

### Admin Tools
- Add/Remove/Set player money
- Player search with autocomplete
- Bulk dirty money wipe
- CSV export
- Audit log
- Discord webhooks

### Framework Support
- QBCore
- QBox  
- ESX (Legacy and older versions with user_accounts table)
- Standalone (via exports)

## Requirements

- oxmysql
- QBCore/QBox/ESX (optional, auto-detected)

## Installation

1. Put `caticus_economy_dashboard` in your resources folder

2. Run the SQL file:
```sql
mysql -u username -p database_name < sql/install.sql
```

3. Edit `config.lua`

4. Add to server.cfg:
```cfg
ensure oxmysql
ensure caticus_economy_dashboard
```

5. Restart server

## Configuration

### Admin Permissions
```lua
Config.AdminPermissions = {
    qbcore = {'god', 'admin'},
    qbox = {'god', 'admin'},
    esx = {'superadmin', 'admin'},
    acePermission = 'economy.dashboard',
}
```

### Discord
```lua
Config.Discord = {
    enabled = true,
    alertWebhook = 'https://discord.com/api/webhooks/...',
    dailyReportWebhook = '',
    adminLogWebhook = '',
    botName = 'Economy Dashboard',
}
```

## Usage

Open with `/economydash`

Close with ESC

## Standalone Exports

```lua
exports['caticus_economy_dashboard']:LogFaucet(identifier, amount, 'jobs', 'Trucking delivery')
exports['caticus_economy_dashboard']:LogSink(identifier, amount, 'vehicles', 'Car purchase')
exports['caticus_economy_dashboard']:LogTransfer(fromId, toId, amount, 'Player trade')
```

## Troubleshooting

**Dashboard won't open** - Check admin permissions, check console errors

**No data** - Run install.sql, check framework detection

**Framework not detected** - Set `Config.Framework = 'qbcore'` manually

## Debug

Set `Config.Debug = true` in config

```
ecodebug totals
ecodebug today  
ecodebug test
```

