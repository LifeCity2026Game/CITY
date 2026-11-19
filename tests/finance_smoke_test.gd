extends SceneTree

const LEDGER_SCRIPT = preload("res://scripts/ownership_ledger.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var saved_ledger_path: String = ProjectSettings.globalize_path("user://ownership_ledger.json")
	if FileAccess.file_exists("user://ownership_ledger.json"):
		DirAccess.remove_absolute(saved_ledger_path)
	var ledger := Node.new()
	ledger.name = "FinanceTestLedger"
	ledger.set_script(LEDGER_SCRIPT)
	root.add_child(ledger)
	await process_frame

	print("FINANCE_CHECKPOINT_ACCOUNT")
	ledger.balances[1] = 20000
	ledger.request_open_bank_account("1234")
	var accounts: Array[Dictionary] = ledger.get_accounts_for_peer(1)
	assert(accounts.size() == 1, "account creation failed")
	var account: Dictionary = accounts[0]
	var account_number := str(account.get("number", ""))
	assert(account_number.length() == 8 and account_number.is_valid_int(), "account number must be 8 numeric digits")
	assert(str(ledger.bank_accounts[account_number].pin_hash) != "1234", "PIN must not be stored in plaintext")

	print("FINANCE_CHECKPOINT_CHEQUE")
	ledger.request_issue_cheque(account_number, "1234", 6000)
	assert(not ledger.cheque_book.is_empty(), "cheque issuance failed")
	var cheque_id := str(ledger.cheque_book.keys()[0])
	ledger._cheque_purchase(1, cheque_id, "گوشی هوشمند")
	assert(ledger.cheque_book[cheque_id].spends.size() == 1, "cheque purchase was not recorded")

	ledger.bank_accounts[account_number].balance = 0
	ledger.game_clock_seconds = 360.0
	print("FINANCE_CHECKPOINT_SETTLEMENT")
	ledger._settle_due_cheques()
	assert(bool(ledger.cheque_spending_ban.get("1", false)), "dishonoured cheque did not restrict cheque issuance")
	assert(not ledger.prison_records.is_empty(), "dishonoured cheque did not create prison record")
	var spend: Dictionary = ledger.cheque_book[cheque_id].spends[0]
	assert(str(spend.status) == "برگشت‌خورده", "cheque did not bounce")
	var doc_id := str(spend.document_id)
	assert(str(ledger.documents[doc_id].status) == "repossessed", "purchased item was not repossessed")

	print("FINANCE_CHECKPOINT_PARDON")
	assert(ledger.pardon_cheque_ban(1, 1, "آزمون بخشودگی"), "creator pardon failed")
	assert(not bool(ledger.cheque_spending_ban.get("1", false)), "pardon did not restore cheque eligibility")
	var prison_id := str(ledger.prison_records.keys()[0])
	assert(ledger.release_prisoner(1, prison_id, "آزمون آزادی"), "creator release failed")

	ledger.bank_accounts[account_number].balance = 10000
	print("FINANCE_CHECKPOINT_PURCHASE")
	ledger._account_purchase(1, account_number, "1234", "گوشی هوشمند")
	assert(ledger.central_bank_treasury == 450, "10 percent tax was not booked")
	assert(ledger.central_bank_withdraw(1, account_number, 100, "آزمون برداشت خزانه"), "Central Bank withdrawal failed")
	assert(ledger.central_bank_treasury == 350, "Central Bank treasury withdrawal amount is incorrect")

	var profile: Dictionary = ledger.get_citizen_full_record(str(account.citizen_id))
	assert(not profile.is_empty(), "citizen full record lookup failed")
	assert(profile.accounts.size() == 1, "citizen bank account missing from profile")
	assert(not profile.cheques.is_empty(), "citizen cheque history missing from profile")
	var npc_account_count := 0
	var npc_account_number := ""
	for npc_number in ledger.bank_accounts.keys():
		var npc_account: Dictionary = ledger.bank_accounts[npc_number]
		if str(npc_account.get("owner_type", "")) == "npc":
			npc_account_count += 1
			npc_account_number = str(npc_number)
	assert(npc_account_count >= 6, "NPC bank accounts were not seeded")
	print("FINANCE_CHECKPOINT_SHARED_CARD")
	ledger.balances[2] = 0
	ledger.bank_accounts[account_number].balance = 10000
	ledger._set_account_share(1, account_number, 2, true)
	assert(bool(ledger.shared_account_access[account_number].get("2", false)), "owner did not grant shared card access")
	var before_shared_purchase := int(ledger.bank_accounts[account_number].balance)
	ledger._account_purchase(2, account_number, "", "گوشی هوشمند", true)
	assert(int(ledger.bank_accounts[account_number].balance) == before_shared_purchase - 4500, "shared card purchase did not debit owner account")
	var shared_doc_found := false
	for doc in ledger.documents.values():
		if int(doc.get("owner_peer_id", -1)) == 2 and str(doc.get("item_id", "")) == "گوشی هوشمند" and str(doc.get("history", []).back().get("event", "")) == "shared_card_purchase":
			shared_doc_found = true
	assert(shared_doc_found, "shared card purchase did not issue buyer ownership document")
	ledger._set_account_share(1, account_number, 2, false)
	assert(not bool(ledger.shared_account_access[account_number].get("2", false)), "owner could not revoke shared card access")
	var balance_after_revoke := int(ledger.bank_accounts[account_number].balance)
	ledger._account_purchase(2, account_number, "", "گوشی هوشمند", true)
	assert(int(ledger.bank_accounts[account_number].balance) == balance_after_revoke, "revoked player was still able to spend")
	print("FINANCE_CHECKPOINT_CENTRAL_BANK")
	assert(ledger.set_role_permissions(1, 2, {"view_central_bank": true, "central_bank_withdraw": true, "view_prison_records": true}), "creator could not assign Central Bank manager permissions")
	assert(not ledger.get_central_bank_snapshot(2).is_empty(), "authorized Central Bank manager could not view the treasury")
	assert(ledger.central_bank_withdraw(2, npc_account_number, 50, "آزمون مدیر بانک مرکزی"), "authorized manager could not withdraw treasury funds")
	assert(not ledger.central_bank_withdraw(3, npc_account_number, 50, "unauthorized"), "unauthorized player withdrew Central Bank funds")

	print("FINANCE_SMOKE_TEST_PASS")
	quit(0)
