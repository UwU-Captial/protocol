import { ethers } from 'hardhat';

import BridgePoolArtifact from '../artifacts/contracts/BridgePool.sol/BridgePool.json';
import MiningPoolArtifact from '../artifacts/contracts/MiningPool.sol/MiningPool.json';

import { MiningPool } from '../type/MiningPool';
import { BridgePool } from '../type/BridgePool';

import { promises } from 'fs';

async function main() {
	const signer = await ethers.getSigners();

	try {
		let data = await promises.readFile('contracts.json', 'utf-8');
		let dataParse = JSON.parse(data.toString());

		const debaseBridgePool = ((await ethers.getContractAt(
			BridgePoolArtifact.abi,
			dataParse['debaseBridgePool'],
			signer[0]
		)) as any) as BridgePool;

		const debaseDaiBridgePool = ((await ethers.getContractAt(
			BridgePoolArtifact.abi,
			dataParse['debaseDaiBridgePool'],
			signer[0]
		)) as any) as BridgePool;

		const uwuMiningPool = ((await ethers.getContractAt(
			MiningPoolArtifact.abi,
			dataParse['uwuBusdLpMiningPool'],
			signer[0]
		)) as any) as MiningPool;

		await debaseBridgePool.startPool();
		await debaseDaiBridgePool.startPool();
		await uwuMiningPool.startPool();
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
