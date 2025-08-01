// Corrected: Added missing imports
use core::byte_array::ByteArray;
use core::integer::u256;
use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
use openzeppelin::introspection::src5::SRC5Component;
use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
use rwax::events::factory::{
    AssetMetadataUpdated, AssetTokenized, TokenizerRoleGranted, TokenizerRoleRevoked,
};
use rwax::interfaces::irwa_factory::IRWAFactory;
use rwax::structs::asset::AssetData;
use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use starknet::{ContractAddress, get_caller_address};

const TOKENIZER_ROLE: felt252 = selector!("TOKENIZER_ROLE");
const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");

#[starknet::contract]
pub mod RWAFactory {
    // Note: All imports were moved outside the mod block as per your original code.
    // If you were to follow a different pattern, they might be placed here.
    use super::{
        AccessControlComponent, AssetData, AssetMetadataUpdated, AssetTokenized, ByteArray,
        ContractAddress, DEFAULT_ADMIN_ROLE, ERC721Component, ERC721HooksEmptyImpl, IRWAFactory,
        Map, SRC5Component, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess, TOKENIZER_ROLE, TokenizerRoleGranted, TokenizerRoleRevoked,
        get_caller_address, u256,
    };

    // === Component Mixins ===
    // component!(path: SRC5Component, storage: src5, event: SRC5Event);
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::get_caller_address;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use super::*;

    component!(path: AccessControlComponent, storage: accessor_control, event: AccessEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    // Implement SRC5 mixin
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

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
    pub enum Event {
        // Corrected: Updated event syntax to use #[flat]
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        AccessEvent: AccessControlComponent::Event,
        AssetTokenized: AssetTokenized,
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
        self.erc721.initializer(name, symbol, base_uri);
        // The admin now has the DEFAULT_ADMIN_ROLE
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin);
        self.accesscontrol._grant_role(TOKENIZER_ROLE, admin);

        self.token_counter.write(0_u256);

        self.fractionalization_module.write(fractionalization_module);
    }

    // === IRWAFactory Interface Implementation ===
    #[abi(embed_v0)]
    impl RWAFactoryImpl of IRWAFactory<ContractState> {
        fn tokenize_asset(
            ref self: ContractState, owner: ContractAddress, asset_data: AssetData,
        ) -> u256 {
            self.accesscontrol.assert_only_role(TOKENIZER_ROLE);

            let token_id = self.token_counter.read() + 1;
            self.token_counter.write(token_id);

            let asset_type = asset_data.asset_type;
            self.asset_data.write(token_id, asset_data.clone());
            self.erc721.mint(owner, token_id);

            self.emit(AssetTokenized { token_id, owner, asset_type, asset_data });

            token_id
        }
        fn update_asset_metadata(ref self: ContractState, token_id: u256, new_data: AssetData) {
            // Check that the token exists
            let owner = self.erc721.owner_of(token_id);

            // Check that caller is either owner or approved operator
            let caller = get_caller_address();
            let is_owner = caller == owner;
            let is_approved = self.erc721.is_approved_for_all(owner, caller)
                || self.erc721.get_approved(token_id) == caller;

            assert(is_owner || is_approved, 'Not authorized');

            // Update asset_data with new metadata
            self.asset_data.write(token_id, new_data.clone());

            // Emit AssetMetadataUpdated event
            self.emit(AssetMetadataUpdated { token_id, updater: caller, new_data });
        }

        // TODO: grant_tokenizer_role
        fn grant_tokenizer_role(ref self: ContractState, account: ContractAddress) {
            // Check that caller has DEFAULT_ADMIN_ROLE
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);

            // Grant the TOKENIZER_ROLE to the specified account
            self.accesscontrol._grant_role(TOKENIZER_ROLE, account);

            // Emit the TokenizerRoleGranted event
            let granter = get_caller_address();
            self.emit(TokenizerRoleGranted { account, granter });

        }

        // TODO: revoke_tokenizer_role
        fn revoke_tokenizer_role(ref self: ContractState, account: ContractAddress) {}

        // TODO: get_asset_data

            // remove this and implement the function, placed this so that function
            // signature won't be returning error.
            AssetData {
                asset_type: 'REAL_ESTATE',
                name: "Test Property",
                description: "A test property",
                value_usd: 100,
                legal_doc_uri: "ipfs://test",
                image_uri: "ipfs://test",
                location: "Test Location",
                created_at: 100,
            }
        }

        fn has_tokenizer_role(self: @ContractState, account: ContractAddress) -> bool {
            self.accessor_control.has_role(TOKENIZER_ROLE, account)
        }

        // TODO: get_total_assets
        fn get_total_assets(self: @ContractState) -> u256 {
            0
        }

        fn get_fractionalization_module(self: @ContractState) -> ContractAddress {
            // self.fractionalization_module.read()
            get_caller_address()
        }
    }
}

