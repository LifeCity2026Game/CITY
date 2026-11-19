extends SceneTree

const LEDGER_SCRIPT = preload("res://scripts/ownership_ledger.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ledger := Node.new()
	ledger.name = "FinanceTestLedger"
	ledger.set_script(LEDGER_SCRIPT)
	root.add_child(ledger)
	await process_frame

	ledger.balances[1] = 20000
	ledger.request_open_bank_account("1234")
	var accounts: Array[Dictionary] = ledger.get_accounts_for_peer(1)
	assert(accounts.size() == 1, "account creation failed")
	var account: Dictionary = accounts[0]
	var account_number := str(account.get("number", ""))
	assert(account_number.length() == 8 and account_number.is_valid_int(), "account number must be 8 numeric digits")
	assert(str(ledger.bank_accounts[account_number].pin_hash) != "1234", "PIN must not be stored in plaintext")

	ledger.request_issue_cheque(account_number, "1234", 6000)
	assert(not ledger.cheque_book.is_empty(), "cheque issuance failed")
	var cheque_id := str(ledger.cheque_book.keys()[0])
	ledger._cheque_purchase(1, cheque_id, "گوشی هوشمند")
	assert(ledger.cheque_book[cheque_id].spends.size() == 1, "cheque purchase was not recorded")

	ledger.bank_accounts[account_number].balance = 0
	ledger.game_clock_seconds = 360.0
	ledger._settle_due_cheques()
	assert(bool(ledger.cheque_spending_ban.get("1", false)), "dishonoured cheque did not restrict cheque issuance")
	assert(not ledger.prison_records.is_empty(), "dishonoured cheque did not create prison record")
	var spend: Dictionary = ledger.cheque_book[cheque_id].spends[0]
	assert(str(spend.status) == "برگشت‌خورده", "cheque did not bounce")
	var doc_id := str(spend.document_id)
	assert(str(ledger.documents[doc_id].status) == "repossessed", "purchased item was not repossessed")

	assert(ledger.pardon_cheque_ban(1, 1, "آزمون بخشودگی"), "creator pardon failed")
	assert(not bool(ledger.cheque_spending_ban.get("1", false)), "pardon did not restore cheque eligibility")
	var prison_id := str(ledger.prison_records.keys()[0])
	assert(ledger.release_prisoner(1, prison_id, "آزمون آزادی"), "creator release failed")

	ledger.bank_accounts[account_number].balance = 10000
	ledger._account_purchase(1, account_number, "1234", "گوشی هوشمند")
	assert(ledger.central_bank_treasury == 450, "10 percent tax was not booked")
	assert(ledger.central_bank_withdraw(1, account_number, 100, "آزمون برداشت خزانه"), "Central Bank withdrawal failed")
	assert(ledger.central_bank_treasury == 350, "Central Bank treasury withdrawal amount is incorrect")

	var profile: Dictionary = ledger.get_citizen_full_record(str(account.citizen_id))
	assert(not profile.is_empty(), "citizen full record lookup failed")
	assert(profile.accounts.size() == 1, "citizen bank account missing from profile")
	assert(not profile.cheques.is_empty(), "citizen cheque history missing from profile")
	assert(ledger.get_accounts_for_peer(-1).size() == 1, "NPC bank account was not seeded")

	print("FINANCE_SMOKE_TEST_PASS")
	quit(0)
