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
	const account = await signer[0].getAddress();

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
		tx = await seed.transferTokensAndLps(0, 30);
		await tx.wait(1);
		tx = await seed.transferTokensAndLps(31, 60);
		await tx.wait(1);
		tx = await seed.transferTokensAndLps(61, 90);
		await tx.wait(1);
		tx = await seed.transferTokensAndLps(91, 120);
		await tx.wait(1);
		tx = await seed.transferTokensAndLps(121, 150);
		await tx.wait(1);
		tx = await seed.transferTokensAndLps(151, 188);
		await tx.wait(1);
		tx = await seed.withdrawRemainingBnB();
		await tx.wait(1);

		const pair = await seed.pair();

		const time = 60 * 60 * 12 + 60 * 60 * 24 * 3;
		const treasury = '0xbc23987868B0bd549d03A234f610d4203f4d9cf0';

		await debaseBridgePool.initialize(dataParse['uwu'], time, treasury);
		await debaseDaiBridgePool.initialize(dataParse['uwu'], time, treasury);
		await uwuMiningPool.initialize(dataParse['uwu'], pair, time, treasury);

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
