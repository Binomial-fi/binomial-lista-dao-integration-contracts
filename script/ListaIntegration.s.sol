// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin-upgradable/access/AccessControlUpgradeable.sol";

import {ListaIntegration} from "../src/contracts/ListaIntegration.sol";
import {BnWClisBnb} from "../src/contracts/BnWClisBnb.sol";

import {IListaIntegration} from "../src/contracts/interfaces/IListaIntegration.sol";

import {Script} from "forge-std/Script.sol";

contract ListaIntegrationDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        BnWClisBnb bnwClisBnb = new BnWClisBnb("wnomBNB", "wnomBNB");
        ProxyAdmin proxyAdmin = new ProxyAdmin(owner);
        ListaIntegration stakeListaImplementation = new ListaIntegration();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(stakeListaImplementation),
            address(proxyAdmin),
            abi.encodeWithSelector(
                ListaIntegration(stakeListaImplementation).initialize.selector,
                "nomBNB",
                "nomBNB",
                0x2BA4f785a3cC04DC1877fCA650331f00416eE8D1, // helios provider
                0xD57E5321e67607Fab38347D96394e0E58509C506, // delegateTo
                owner, // fee receiver
                5000000000000000000, // 5% fee
                0x90D121a349616674Ab0933fcF435F06580111e30, // simple staking
                address(bnwClisBnb) // bnwclisbnb
            )
        );

        AccessControlUpgradeable(address(proxy)).grantRole(IListaIntegration(address(proxy)).ADMIN_ROLE(), owner);
        bnwClisBnb.grantRole(bnwClisBnb.MINT_BURN_ROLE(), address(proxy));

        vm.stopBroadcast();
    }
}

//# To load the variables in the .env file
// source .env

// # To deploy and verify our contract
// forge script --chain bsc-testnet <scriptPath:contractName> --rpc-url $TESTNET_RPC_URL --broadcast --verify -vvvv

// # To verify the contract
// forge verify-contract <contractAddress> <contractPath:contractName> --chain bsc-testnet --etherscan-api-key $ETHERSCAN_API_KEY
