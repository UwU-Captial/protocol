import { ethers } from 'hardhat';
import { parseEther } from 'ethers/lib/utils';

import UwUArtifact from '../artifacts/contracts/UwU.sol/UwU.json';
import UnUPolicyArtifact from '../artifacts/contracts/UwUPolicy.sol/UwUPolicy.json';
import OrchestratorArtifact from '../artifacts/contracts/Orchestrator.sol/Orchestrator.json';
import BridgePoolArtifact from '../artifacts/contracts/BridgePool.sol/BridgePool.json';
import MiningPoolArtifact from '../artifacts/contracts/MiningPool.sol/MiningPool.json';
import OracleArtifact from '../artifacts/contracts/Oracle.sol/Oracle.json';
import IUniswapV2Router02Artifact from '../artifacts/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol/IUniswapV2Router02.json';
import TokenArtifact from '../artifacts/contracts/mock/Token.sol/Token.json';
import SeedFactoryArtifact from '../artifacts/contracts/Seed.sol/Seed.json';

import { SeedFactory } from '../type/SeedFactory';
import { BridgePoolFactory } from '../type/BridgePoolFactory';
import { MiningPoolFactory } from '../type/MiningPoolFactory';
import { OrchestratorFactory } from '../type/OrchestratorFactory';
import { UwUFactory } from '../type/UwUFactory';
import { UwUPolicyFactory } from '../type/UwUPolicyFactory';
import { TokenFactory } from '../type/TokenFactory';
import { OracleFactory } from '../type/OracleFactory';
import { IUniswapV2Router02 } from '../type/IUniswapV2Router02';

import { promises } from 'fs';

async function main() {
	const signer = await ethers.getSigners();
	const account = await signer[0].getAddress();

	let contractAddresses = {
		factory: '0xd417a0a4b65d24f5ebd0898d9028d92e3592afcc',
		router: '0x07d090e7fcbc6afaa507a3441c7c5ee507c457e6',
		bnb: '',
		busd: '',
		bnbBusdLp: '',
		uwu: '',
		uwuPolicy: '',
		orchestrator: '',
		seed: '',
		debaseBridgePool: '',
		debaseEthBridgePool: '',
		uwuMiningPool: '',
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

		const oracleFactory = (new ethers.ContractFactory(
			OracleArtifact.abi,
			OracleArtifact.bytecode,
			signer[0]
		) as any) as OracleFactory;

		const bnbFactory = (new ethers.ContractFactory(
			TokenArtifact.abi,
			TokenArtifact.bytecode,
			signer[0]
		) as any) as TokenFactory;

		const busdFactory = (new ethers.ContractFactory(
			TokenArtifact.abi,
			TokenArtifact.bytecode,
			signer[0]
		) as any) as TokenFactory;

		const uwuFactory = (new ethers.ContractFactory(
			UwUArtifact.abi,
			UwUArtifact.bytecode,
			signer[0]
		) as any) as UwUFactory;

		const router = new ethers.Contract(
			contractAddresses.router,
			IUniswapV2Router02Artifact.abi,
			signer[0]
		) as IUniswapV2Router02;

		const seedFactory = (new ethers.ContractFactory(
			SeedFactoryArtifact.abi,
			SeedFactoryArtifact.bytecode,
			signer[0]
		) as any) as SeedFactory;

		const bnb = await bnbFactory.deploy('BNB', 'BNB');
		const busd = await busdFactory.deploy('BUSD', 'BUSD');
		const orchestrator = await orchestratorFactory.deploy();
		const uwuPolicy = await uwuPolicyFactory.deploy();
		const uwu = await uwuFactory.deploy();
		const debaseBridgePool = await bridgePoolFactory.deploy();
		const debaseEthBridgePool = await bridgePoolFactory.deploy();
		const uwuMiningPool = await miningPoolFactory.deploy();
		const seed = await seedFactory.deploy();

		let tx = await bnb.approve(router.address, parseEther('500000'));
		await tx.wait(1);
		tx = await busd.approve(router.address, parseEther('1000000'));
		await tx.wait(1);

		tx = await router.addLiquidity(
			bnb.address,
			busd.address,
			parseEther('500000'),
			parseEther('1000000'),
			parseEther('500000'),
			parseEther('1000000'),
			account,
			1624604055
		);
		await tx.wait(1);

		await orchestrator.initialize(
			contractAddresses.factory,
			uwu.address,
			uwuPolicy.address,
			debaseBridgePool.address,
			debaseEthBridgePool.address,
			uwuMiningPool.address,
			parseEther('950000'),
			60 * 60 * 7
		);

		await uwuPolicy.initialize(uwu.address, orchestrator.address);

		contractAddresses.uwu = uwu.address;
		contractAddresses.uwuPolicy = uwuPolicy.address;
		contractAddresses.bnb = bnb.address;
		contractAddresses.busd = busd.address;
		contractAddresses.orchestrator = orchestrator.address;
		contractAddresses.debaseBridgePool = debaseBridgePool.address;
		contractAddresses.debaseEthBridgePool = debaseEthBridgePool.address;
		contractAddresses.uwuMiningPool = uwuMiningPool.address;
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
