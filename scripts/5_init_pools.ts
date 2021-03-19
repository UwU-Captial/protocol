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

		let tx = await seed.swapBnbAndCreatePancakePair();
		await tx.wait(1);
		tx = await seed.transferTokensAndLps(0, 0);
		await tx.wait(1);
		tx = await seed.withdrawRemainingBnB();
		await tx.wait(1);

		const pair = await seed.pair();

		await debaseBridgePool.initialize(dataParse['uwu'], 60 * 7 * 1);
		await debaseDaiBridgePool.initialize(dataParse['uwu'], 60 * 7 * 1);
		await uwuMiningPool.initialize(dataParse['uwu'], pair, 60 * 3 * 1);

		dataParse['uwuBusdLp'] = pair;
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
