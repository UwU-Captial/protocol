import { ethers } from 'hardhat';
import { parseEther, parseUnits } from 'ethers/lib/utils';
import { BigNumber } from 'ethers';

import UwUArtifact from '../artifacts/contracts/UwU.sol/UwU.json';
import UnUPolicyArtifact from '../artifacts/contracts/UwUPolicy.sol/UwUPolicy.json';
import OrchestratorArtifact from '../artifacts/contracts/Orchestrator.sol/Orchestrator.json';
import BridgePoolArtifact from '../artifacts/contracts/BridgePool.sol/BridgePool.json';
import MiningPoolArtifact from '../artifacts/contracts/MiningPool.sol/MiningPool.json';
import TimelockArtifact from '../artifacts/contracts/Timelock.sol/Timelock.json';
import OracleArtifact from '../artifacts/contracts/Oracle.sol/Oracle.json';
import SeedFactoryArtifact from '../artifacts/contracts/Seed.sol/Seed.json';
import IUniswapV2Router02Artifact from '../artifacts/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol/IUniswapV2Router02.json';
import IUniswapV2PairArtifact from '../artifacts/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol/IUniswapV2Pair.json';
import TokenArtifact from '../artifacts/contracts/mock/Token.sol/Token.json';

import { BridgePool } from '../type/BridgePoolFactory';
import { MiningPool } from '../type/MiningPoolFactory';
import { Orchestrator } from '../type/OrchestratorFactory';
import { Timelock } from '../type/TimelockFactory';
import { UwU } from '../type/UwUFactory';
import { UwUPolicy } from '../type/UwUPolicyFactory';
import { Token } from '../type/TokenFactory';
import { Oracle } from '../type/OracleFactory';
import { IUniswapV2Router02 } from '../type/IUniswapV2Router02';
import { Seed } from '../type/SeedFactory';
import { IUniswapV2Pair } from '../type/IUniswapV2Pair';

import { promises } from 'fs';

async function main() {
	const signer = await ethers.getSigners();
	const account = await signer[0].getAddress();

	try {
		let data = await promises.readFile('contracts.json', 'utf-8');
		let dataParse = JSON.parse(data.toString());

		const orchestrator = ((await ethers.getContractAt(
			OrchestratorArtifact.abi,
			dataParse['orchestrator'],
			signer[0]
		)) as any) as Orchestrator;

		const router = new ethers.Contract(
			'0x07d090e7fcbc6afaa507a3441c7c5ee507c457e6',
			IUniswapV2Router02Artifact.abi,
			signer[0]
		) as IUniswapV2Router02;

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
