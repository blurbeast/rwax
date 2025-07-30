#[cfg(test)]
mod test {
    use rwax::interfaces::irwa_factory::{IRWAFactoryDispatcher, IRWAFactoryDispatcherTrait};
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
        start_cheat_caller_address_global, stop_cheat_caller_address_global,
    };
    // use rwax::structs::asset::AssetData;
    use starknet::ContractAddress;

    fn deploy_rwa_factory() -> IRWAFactoryDispatcher {
        let contract = declare("RWAFactory").unwrap().contract_class();

        let mut constructor_calldata = array![];
        let name: ByteArray = "rwa_token";
        let symbol: ByteArray = "RWA";
        let base_uri: ByteArray = "https://api.rwax.com/metadata/";
        let admin: ContractAddress = 0x123.try_into().unwrap();
        let fractionalization_module: ContractAddress = 0x456.try_into().unwrap();

        name.serialize(ref constructor_calldata);
        symbol.serialize(ref constructor_calldata);
        base_uri.serialize(ref constructor_calldata);
        admin.serialize(ref constructor_calldata);
        fractionalization_module.serialize(ref constructor_calldata);

        // let constructor_calldata = array![name, admin.into(),
        // fractionalization_module.into();
        start_cheat_caller_address_global(admin);
        let (address, _) = contract.deploy(@constructor_calldata).unwrap();
        IRWAFactoryDispatcher { contract_address: address }
    }

    #[test]
    fn test_admin_can_revoke_tokenizer_role() {
        let admin: ContractAddress = 0x123.try_into().unwrap();
        let target_account: ContractAddress = 0x789.try_into().unwrap();
        let dispatcher = deploy_rwa_factory();

        // Cheat as admin and manually grant tokenizer role directly in storage
        start_cheat_caller_address(dispatcher.contract_address, admin);
        dispatcher.grant_tokenizer_role(target_account);

        // // Ensure role was granted
        let has_role = dispatcher.has_tokenizer_role(target_account);
        assert!(has_role, "Expected tokenizer role to be granted");
        // // Revoke tokenizer role
        start_cheat_caller_address_global(admin);
        dispatcher.revoke_tokenizer_role(target_account);

        // // // Ensure role was revoked
        let has_role_after = dispatcher.has_tokenizer_role(target_account);
        assert!(!has_role_after, "Expected tokenizer role to be revoked");
    }

    #[test]
    #[should_panic]
    fn test_non_admin_cannot_revoke_roles() {
        let admin: ContractAddress = 0x123.try_into().unwrap();
        let target_account: ContractAddress = 0x789.try_into().unwrap();
        let factory = deploy_rwa_factory();

        // First grant the role (as admin)
        start_cheat_caller_address_global(admin);
        factory.grant_tokenizer_role(target_account);
        stop_cheat_caller_address_global();
        // Verify role was granted
        let has_role = factory.has_tokenizer_role(target_account);
        assert!(has_role, "Expected tokenizer role to be granted");

        // Attempt to revoke as non-admin - should panic
        start_cheat_caller_address_global(target_account);
        factory.revoke_tokenizer_role(target_account);

        // unreachable but just in case
        let has_role = factory.has_tokenizer_role(target_account);
        assert!(has_role, "Expected tokenizer role to be granted");
    }
}
