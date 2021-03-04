import { ethers } from 'hardhat';
import { parseEther, parseUnits } from 'ethers/lib/utils';
import { BigNumber } from 'ethers';

import BridgePoolArtifact from '../artifacts/contracts/BridgePool.sol/BridgePool.json';
import BridgePool from '../type/BridgePool';

import { promises } from 'fs';

async function main() {
	const signer = await ethers.getSigners();
	const account = await signer[0].getAddress();

	try {
		let data = await promises.readFile('contracts.json', 'utf-8');
		let dataParse = JSON.parse(data.toString());

		const seed = ((await ethers.getContractAt(SeedArtifact.abi, dataParse['seed'], signer[0])) as any) as Seed;
		await seed.startSeed();
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
