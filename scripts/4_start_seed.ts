import { ethers } from 'hardhat';

import SeedArtifact from '../artifacts/contracts/Seed.sol/Seed.json';
import { Seed } from '../type/Seed';

import { promises } from 'fs';

async function main() {
	const signer = await ethers.getSigners();

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
