extends SceneTree

const LEDGER_SCRIPT = preload("res://scripts/ownership_ledger.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists("user://ownership_ledger.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ownership_ledger.json"))
	var ledger := Node.new()
	ledger.name = "OnlineStoreTestLedger"
	ledger.set_script(LEDGER_SCRIPT)
	root.add_child(ledger)
	await process_frame
	assert(ledger.store_inventory.has("گوشی هوشمند"), "store inventory was not initialized")
	assert(int(ledger.store_inventory["گوشی هوشمند"]) > 0, "initial store stock must be positive")
	var accounts: Array[Dictionary] = ledger.get_accounts_for_peer(1)
	ledger.request_open_bank_account("1111")
	ledger.balances[1] = 20000
	ledger.request_open_bank_account("4321")
	accounts = ledger.get_accounts_for_peer(1)
	assert(accounts.size() == 2, "test bank accounts were not created")
	var account_number := str(accounts[1].get("number", ""))
	ledger.bank_accounts[account_number].balance = 20000
	var stock_before := int(ledger.store_inventory["گوشی هوشمند"])
	ledger._store_checkout(1, account_number, "4321", "گوشی هوشمند", 2)
	assert(int(ledger.store_inventory["گوشی هوشمند"]) == stock_before - 2, "checkout did not decrement inventory by quantity")
	assert(int(ledger.bank_accounts[account_number].balance) == 11000, "checkout did not debit the bank account correctly")
	assert(ledger.store_orders.size() == 1, "checkout did not create an order")
	var order_id := str(ledger.store_orders.keys()[0])
	assert(int(ledger.store_orders[order_id].get("quantity", 0)) == 2, "order quantity was not recorded")
	assert(str(ledger.store_orders[order_id].get("status", "")) == "در حال ارسال", "new order should be awaiting delivery")
	ledger._store_process_deliveries(float(ledger.store_orders[order_id].get("deliver_at", 0.0)) + 1.0)
	assert(str(ledger.store_orders[order_id].get("status", "")) == "تحویل شد", "delivery processor did not complete due order")
	assert(ledger._store_restock(2, "گوشی هوشمند", 5) == false, "non-owner was able to restock inventory")
	assert(ledger._store_restock(1, "گوشی هوشمند", 5), "creator could not restock inventory")
	assert(int(ledger.store_inventory["گوشی هوشمند"]) == stock_before - 2 + 5, "restock quantity was not applied")
	print("ONLINE_STORE_SMOKE_TEST_PASS")
	quit(0)
