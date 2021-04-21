import { ethers } from 'hardhat';
import { formatEther, parseEther } from 'ethers/lib/utils';

import BridgePoolArtifact from '../artifacts/contracts/BridgePool.sol/BridgePool.json';
import MiningPoolArtifact from '../artifacts/contracts/MiningPool.sol/MiningPool.json';
import UwUArtifacts from '../artifacts/contracts/UwU.sol/UwU.json';

import { BridgePool } from '../type/BridgePool';
import { MiningPool } from '../type/MiningPool';
import { UwU } from '../type/UwU';

import { promises } from 'fs';

async function main() {
	const signer = await ethers.getSigners();

	let data = await promises.readFile('contracts.json', 'utf-8');
	let dataParse = JSON.parse(data.toString());

	let userData = await promises.readFile('users.json', 'utf-8');
	let userDataParse = JSON.parse(userData.toString());

	try {
		const uwuMining = ((await ethers.getContractAt(
			MiningPoolArtifact.abi,
			dataParse['uwuBusdLpMiningPool'],
			signer[0]
		)) as any) as MiningPool;

		const debaseBridge = ((await ethers.getContractAt(
			BridgePoolArtifact.abi,
			dataParse['debaseBridgePool'],
			signer[0]
		)) as any) as BridgePool;

		const debaseDaiBridge = ((await ethers.getContractAt(
			BridgePoolArtifact.abi,
			dataParse['debaseDaiBridgePool'],
			signer[0]
		)) as any) as BridgePool;

		const uwu = ((await ethers.getContractAt(UwUArtifacts.abi, dataParse['uwu'], signer[0])) as any) as UwU;

		const snap1 = 6293772;
		const snap2 = 6302088;
		const snap3 = 6313600;

		const snap1Arr = [];
		const snap2Arr = [];
		const snap3Arr = [];

		for (let index = 0; index < userDataParse.length; index++) {
			const user = userDataParse[index];

			let balsnap1 = await uwu.balanceOf(user, { blockTag: snap1 });
			let earned1snap1 = await uwuMining.earned(user, { blockTag: snap1 });
			let earned2snap1 = await debaseBridge.earned(user, { blockTag: snap1 });
			let earned3snap1 = await debaseDaiBridge.earned(user, { blockTag: snap1 });

			let balsnap2 = await uwu.balanceOf(user, { blockTag: snap2 });
			let earned1snap2 = await uwuMining.earned(user, { blockTag: snap2 });
			let earned2snap2 = await debaseBridge.earned(user, { blockTag: snap2 });
			let earned3snap2 = await debaseDaiBridge.earned(user, { blockTag: snap2 });

			let balsnap3 = await uwu.balanceOf(user, { blockTag: snap3 });
			let earned1snap3 = await uwuMining.earned(user, { blockTag: snap3 });
			let earned2snap3 = await debaseBridge.earned(user, { blockTag: snap3 });
			let earned3snap3 = await debaseDaiBridge.earned(user, { blockTag: snap3 });

			snap1Arr.push({
				user: user,
				balance:
					formatEther(balsnap1) +
					formatEther(earned1snap1) +
					formatEther(earned2snap1) +
					formatEther(earned3snap1)
			});

			snap2Arr.push({
				user: user,
				balance:
					formatEther(balsnap2) +
					formatEther(earned1snap2) +
					formatEther(earned2snap2) +
					formatEther(earned3snap2)
			});

			snap3Arr.push({
				user: user,
				balance:
					formatEther(balsnap3) +
					formatEther(earned1snap3) +
					formatEther(earned2snap3) +
					formatEther(earned3snap3)
			});
		}

		const dataStore1 = JSON.stringify(snap1Arr);
		const dataStore2 = JSON.stringify(snap2Arr);
		const dataStore3 = JSON.stringify(snap3Arr);

		await promises.writeFile('snap1.json', dataStore1);
		await promises.writeFile('snap2.json', dataStore2);
		await promises.writeFile('snap3.json', dataStore3);

		console.log('JSON data is saved.');
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
