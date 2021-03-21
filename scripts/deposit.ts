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
	const account2 = await signer[1].getAddress();

	try {
		let data = await promises.readFile('contracts.json', 'utf-8');
		let dataParse = JSON.parse(data.toString());

		const bnb = ((await ethers.getContractAt(IWBNBArtifact.abi, dataParse['bnb'], signer[0])) as any) as Iwbnb;
		const bnb2 = ((await ethers.getContractAt(IWBNBArtifact.abi, dataParse['bnb'], signer[1])) as any) as Iwbnb;
		const bnb3 = ((await ethers.getContractAt(IWBNBArtifact.abi, dataParse['bnb'], signer[2])) as any) as Iwbnb;
		const bnb4 = ((await ethers.getContractAt(IWBNBArtifact.abi, dataParse['bnb'], signer[3])) as any) as Iwbnb;
		const bnb5 = ((await ethers.getContractAt(IWBNBArtifact.abi, dataParse['bnb'], signer[4])) as any) as Iwbnb;
		const bnb6 = ((await ethers.getContractAt(IWBNBArtifact.abi, dataParse['bnb'], signer[5])) as any) as Iwbnb;

		const seed = ((await ethers.getContractAt(SeedArtifact.abi, dataParse['seed'], signer[0])) as any) as Seed;
		const seed2 = ((await ethers.getContractAt(SeedArtifact.abi, dataParse['seed'], signer[1])) as any) as Seed;
		const seed3 = ((await ethers.getContractAt(SeedArtifact.abi, dataParse['seed'], signer[2])) as any) as Seed;
		const seed4 = ((await ethers.getContractAt(SeedArtifact.abi, dataParse['seed'], signer[3])) as any) as Seed;
		const seed5 = ((await ethers.getContractAt(SeedArtifact.abi, dataParse['seed'], signer[4])) as any) as Seed;
		const seed6 = ((await ethers.getContractAt(SeedArtifact.abi, dataParse['seed'], signer[5])) as any) as Seed;

		let amount = await seed.walletBNBCap();

		await bnb.deposit({ value: amount });
		await bnb2.deposit({ value: amount });
		await bnb3.deposit({ value: amount });
		await bnb4.deposit({ value: amount });
		await bnb5.deposit({ value: amount });
		await bnb6.deposit({ value: amount });

		await bnb.approve(seed.address, amount);
		await bnb2.approve(seed.address, amount);
		await bnb3.approve(seed.address, amount);
		await bnb4.approve(seed.address, amount);
		await bnb5.approve(seed.address, amount);
		await bnb6.approve(seed.address, amount);

		await seed.deposit(amount);
		await seed2.deposit(amount);
		await seed3.deposit(amount);
		await seed4.deposit(amount);
		await seed5.deposit(amount);
		await seed6.deposit(amount.div(2));
		await seed6.deposit(amount.div(2));
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
