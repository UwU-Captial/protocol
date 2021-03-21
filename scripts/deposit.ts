import { ethers } from 'hardhat';

import SeedArtifact from '../artifacts/contracts/Seed.sol/Seed.json';
import { Seed } from '../type/Seed';
import IWBNBArtifact from '../artifacts/contracts/interfaces/IWBNB.sol/IWBNB.json';

import { promises } from 'fs';
import { Iwbnb } from '../type/Iwbnb';
import { formatEther } from '@ethersproject/units';

async function main() {
	const signer = await ethers.getSigners();
	const account = await signer[0].getAddress();

	try {
		let data = await promises.readFile('contracts.json', 'utf-8');
		let dataParse = JSON.parse(data.toString());

		const bnb = ((await ethers.getContractAt(IWBNBArtifact.abi, dataParse['bnb'], signer[0])) as any) as Iwbnb;
		const seed = ((await ethers.getContractAt(SeedArtifact.abi, dataParse['seed'], signer[0])) as any) as Seed;
		let amount = await seed.walletBNBCap();

		await bnb.deposit({ value: amount });
		console.log('WBNB Balance', formatEther(await bnb.balanceOf(account)));
		await bnb.approve(seed.address, amount);

		await seed.deposit(amount);
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
