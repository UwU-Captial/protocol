import { ethers } from 'hardhat';

import SeedArtifact from '../artifacts/contracts/Seed.sol/Seed.json';
import { Seed } from '../type/Seed';
import TokenArtifact from '../artifacts/contracts/mock/Token.sol/Token.json';

import { promises } from 'fs';
import { Token } from '../type/Token';

async function main() {
	const signer = await ethers.getSigners();

	try {
		let data = await promises.readFile('contracts.json', 'utf-8');
		let dataParse = JSON.parse(data.toString());

		const bnb = ((await ethers.getContractAt(TokenArtifact.abi, dataParse['bnb'], signer[0])) as any) as Token;
		const seed = ((await ethers.getContractAt(SeedArtifact.abi, dataParse['seed'], signer[0])) as any) as Seed;

		let amount = await seed.BNBCap();

		await bnb.approve(seed.address, amount);
		await seed.deposit(amount);
		// await seed.swapBnbAndCreatePancakePair();
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
