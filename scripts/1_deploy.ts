import { ethers } from 'hardhat';
import { parseEther } from 'ethers/lib/utils';

import UwUArtifact from '../artifacts/contracts/UwU.sol/UwU.json';
import UnUPolicyArtifact from '../artifacts/contracts/UwUPolicy.sol/UwUPolicy.json';
import OrchestratorArtifact from '../artifacts/contracts/Orchestrator.sol/Orchestrator.json';
import BridgePoolArtifact from '../artifacts/contracts/BridgePool.sol/BridgePool.json';
import MiningPoolArtifact from '../artifacts/contracts/MiningPool.sol/MiningPool.json';
import SeedFactoryArtifact from '../artifacts/contracts/Seed.sol/Seed.json';

import { SeedFactory } from '../type/SeedFactory';
import { BridgePoolFactory } from '../type/BridgePoolFactory';
import { MiningPoolFactory } from '../type/MiningPoolFactory';
import { OrchestratorFactory } from '../type/OrchestratorFactory';
import { UwUFactory } from '../type/UwUFactory';
import { UwUPolicyFactory } from '../type/UwUPolicyFactory';

import { promises } from 'fs';

async function main() {
	const signer = await ethers.getSigners();

	let contractAddresses = {
		factory: '0xbcfccbde45ce874adcb698cc183debcf17952812',
		router: '0x05ff2b0db69458a0750badebc4f9e13add608c7f',
		bnb: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
		busd: '0xe9e7cea3dedca5984780bafc599bd69add087d56',
		bnbBusdLp: '0x1b96b92314c44b159149f7e0303511fb2fc4774f',
		uwu: '',
		uwuPolicy: '',
		orchestrator: '',
		seed: '',
		debaseBridgePool: '',
		debaseDaiBridgePool: '',
		uwuBusdLpMiningPool: '',
		uwuBusdLp: '',
		oracle: ''
	};

	try {
		////////////////////////
		/////////////////////////////
		// Remember about that uni factory
		///////////////////////////////

		const orchestratorFactory = (new ethers.ContractFactory(
			OrchestratorArtifact.abi,
			OrchestratorArtifact.bytecode,
			signer[0]
		) as any) as OrchestratorFactory;

		const miningPoolFactory = (new ethers.ContractFactory(
			MiningPoolArtifact.abi,
			MiningPoolArtifact.bytecode,
			signer[0]
		) as any) as MiningPoolFactory;

		const bridgePoolFactory = (new ethers.ContractFactory(
			BridgePoolArtifact.abi,
			BridgePoolArtifact.bytecode,
			signer[0]
		) as any) as BridgePoolFactory;

		const uwuPolicyFactory = (new ethers.ContractFactory(
			UnUPolicyArtifact.abi,
			UnUPolicyArtifact.bytecode,
			signer[0]
		) as any) as UwUPolicyFactory;

		const uwuFactory = (new ethers.ContractFactory(
			UwUArtifact.abi,
			UwUArtifact.bytecode,
			signer[0]
		) as any) as UwUFactory;

		const seedFactory = (new ethers.ContractFactory(
			SeedFactoryArtifact.abi,
			SeedFactoryArtifact.bytecode,
			signer[0]
		) as any) as SeedFactory;

		const orchestrator = await orchestratorFactory.deploy();
		const uwuPolicy = await uwuPolicyFactory.deploy();
		const uwu = await uwuFactory.deploy();
		const debaseBridgePool = await bridgePoolFactory.deploy();
		const debaseEthBridgePool = await bridgePoolFactory.deploy();
		const uwuMiningPool = await miningPoolFactory.deploy();
		const seed = await seedFactory.deploy();

		await orchestrator.initialize(
			uwu.address,
			uwuPolicy.address,
			debaseBridgePool.address,
			debaseEthBridgePool.address,
			uwuMiningPool.address,
			seed.address,
			parseEther('950000'),
			60 * 60 * 7
		);

		await uwuPolicy.initialize(uwu.address, orchestrator.address);

		contractAddresses.uwu = uwu.address;
		contractAddresses.uwuPolicy = uwuPolicy.address;
		contractAddresses.orchestrator = orchestrator.address;
		contractAddresses.debaseBridgePool = debaseBridgePool.address;
		contractAddresses.debaseDaiBridgePool = debaseEthBridgePool.address;
		contractAddresses.uwuBusdLpMiningPool = uwuMiningPool.address;
		contractAddresses.seed = seed.address;

		const data = JSON.stringify(contractAddresses);
		await promises.writeFile('contracts.json', data);
		console.log('JSON data is saved.');
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
