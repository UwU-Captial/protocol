import { ethers } from 'hardhat';

import SeedArtifact from '../artifacts/contracts/Seed.sol/Seed.json';
import BridgePoolArtifact from '../artifacts/contracts/BridgePool.sol/BridgePool.json';
import MiningPoolArtifact from '../artifacts/contracts/MiningPool.sol/MiningPool.json';

import { Seed } from '../type/Seed';
import { MiningPool } from '../type/MiningPool';
import { BridgePool } from '../type/BridgePool';

import { promises } from 'fs';

async function main() {
	const signer = await ethers.getSigners();

	try {
		let data = await promises.readFile('contracts.json', 'utf-8');
		let dataParse = JSON.parse(data.toString());

		const seed = ((await ethers.getContractAt(SeedArtifact.abi, dataParse['seed'], signer[0])) as any) as Seed;

		const debaseBridgePool = ((await ethers.getContractAt(
			BridgePoolArtifact.abi,
			dataParse['debaseBridgePool'],
			signer[0]
		)) as any) as BridgePool;

		const debaseEthBridgePool = ((await ethers.getContractAt(
			BridgePoolArtifact.abi,
			dataParse['debaseEthBridgePool'],
			signer[0]
		)) as any) as BridgePool;

		const uwuMiningPool = ((await ethers.getContractAt(
			MiningPoolArtifact.abi,
			dataParse['uwuMiningPool'],
			signer[0]
		)) as any) as MiningPool;

		let tx = await seed.swapBnbAndCreatePancakePair();
		tx.wait(1);

		await debaseBridgePool.initialize(dataParse['uwu'], 60 * 60 * 2);
		await debaseEthBridgePool.initialize(dataParse['uwu'], 60 * 60 * 2);
		await uwuMiningPool.initialize(dataParse['uwu'], dataParse['busd'], dataParse['factory'], 60 * 60 * 2);

		await debaseBridgePool.startPool();
		await debaseEthBridgePool.startPool();
		await uwuMiningPool.startPool();

		dataParse['uwuBnbLp'] = await seed.pair();
		const updatedData = JSON.stringify(dataParse);
		await promises.writeFile('contracts.json', updatedData);
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
