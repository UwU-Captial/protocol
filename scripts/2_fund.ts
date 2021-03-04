import { ethers } from 'hardhat';

import UwUArtifact from '../artifacts/contracts/UwU.sol/UwU.json';
import { UwU } from '../type/UwU';
import { promises } from 'fs';

async function main() {
	const signer = await ethers.getSigners();

	try {
		let data = await promises.readFile('contracts.json', 'utf-8');
		let dataParse = JSON.parse(data.toString());

		const uwu = ((await ethers.getContractAt(UwUArtifact.abi, dataParse['uwu'], signer[0])) as any) as UwU;
		await uwu.initialize(
			dataParse['debaseBridgePool'],
			1,
			dataParse['debaseEthBridgePool'],
			1,
			dataParse['uwuMiningPool'],
			6,
			dataParse['seed'],
			2,
			dataParse['uwuPolicy'],
			90
		);
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
