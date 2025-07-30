use rwax::events::factory::*;
use rwax::interfaces::irwa_factory::IRWAFactory;
use rwax::structs::asset::AssetData;
use starknet::ContractAddress;

const TOKENIZER_ROLE: felt252 = selector!("TOKENIZER_ROLE");
const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");

#[starknet::contract]
mod RWAFactory {
    // === Component Mixins ===
    // component!(path: SRC5Component, storage: src5, event: SRC5Event);
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::get_caller_address;
    use starknet::storage::{Map, StoragePointerWriteAccess};
    use super::*;

    component!(path: AccessControlComponent, storage: accessor_control, event: AccessEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // #[abi(embed_v0)]
    // impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    // impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    // === Storage ===
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        token_counter: u256,
        asset_data: Map<u256, AssetData>,
        fractionalization_module: ContractAddress,
        #[substorage(v0)]
        accessor_control: AccessControlComponent::Storage,
    }

    // === Events ===
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        AccessEvent: AccessControlComponent::Event,
        //     AssetTokenized: AssetTokenized,
        //     AssetMetadataUpdated: AssetMetadataUpdated,
        TokenizerRoleGranted: TokenizerRoleGranted,
        TokenizerRoleRevoked: TokenizerRoleRevoked,
    }

    // === Constructor Skeleton ===
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        admin: ContractAddress,
        fractionalization_module: ContractAddress,
    ) {
        // self.erc721.initializer(name, symbol, base_uri);
        self.accessor_control.initializer();
        self.accessor_control._grant_role(ADMIN_ROLE, admin);
        // // Store the fractionalization module address
        self.accessor_control.assert_only_role(ADMIN_ROLE);
        self.fractionalization_module.write(fractionalization_module);
    }

    // === IRWAFactory Interface Implementation ===
    #[abi(embed_v0)]
    impl RWAFactoryImpl of IRWAFactory<ContractState> {
        fn tokenize_asset(
            ref self: ContractState, owner: ContractAddress, asset_data: AssetData,
        ) -> u256 {
            // TODO
            // unimplemented!();
            1
        }

        fn update_asset_metadata(
            ref self: ContractState, token_id: u256, new_data: AssetData,
        ) { // TODO
        // unimplemented!();
        }

        fn grant_tokenizer_role(ref self: ContractState, account: ContractAddress) { // TODO
            // unimplemented!();
            // Get the actual admin caller (not the contract address)
            let caller = get_caller_address();

            // // Verify caller has admin role
            self.accessor_control.assert_only_role(ADMIN_ROLE);

            // Check if account already has role
            assert(
                !self.accessor_control.has_role(TOKENIZER_ROLE, account),
                'Account already has role',
            );

            // // Grant the role
            self.accessor_control._grant_role(TOKENIZER_ROLE, account);

            // // Emit event
            self.emit(TokenizerRoleGranted { account, granter: caller });
        }

        fn revoke_tokenizer_role(ref self: ContractState, account: ContractAddress) {
            // TODO
            self.accessor_control.assert_only_role(ADMIN_ROLE);
            // Check if account has TOKENIZER_ROLE
            assert(
                self.accessor_control.has_role(TOKENIZER_ROLE, account),
                'Account does not have role',
            );
            // // Revoke the tokenizer role
            self.accessor_control.revoke_role(TOKENIZER_ROLE, account);
            // Emit event
            self.emit(TokenizerRoleRevoked { account, revoker: get_caller_address() });
        }

        fn get_asset_data(self: @ContractState, token_id: u256) -> AssetData {
            // TODO
            // unimplemented!()
            AssetData {
                asset_type: 0, 
                name: "",
                description: "",
                value_usd: 1000000, 
                legal_doc_uri: "",
                image_uri: "",
                location: "",
                created_at: 0 
            }
        }

        fn has_tokenizer_role(self: @ContractState, account: ContractAddress) -> bool {
            self.accessor_control.has_role(TOKENIZER_ROLE, account)
        }

        fn get_total_assets(self: @ContractState) -> u256 {
            // TODO
            // unimplemented!();
            1
        }

        fn get_fractionalization_module(self: @ContractState) -> ContractAddress {
            // self.fractionalization_module.read()
            get_caller_address() 
        }
    }
}

