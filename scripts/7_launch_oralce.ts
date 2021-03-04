import { ethers } from 'hardhat';

import OracleArtifact from '../artifacts/contracts/Oracle.sol/Oracle.json';
import UwUPolicyArtifact from '../artifacts/contracts/UwUPolicy.sol/UwUPolicy.json';
import { UwUPolicy } from '../type/UwUPolicy';
import { OracleFactory } from '../type/OracleFactory';

import { promises } from 'fs';

async function main() {
	const signer = await ethers.getSigners();

	try {
		let data = await promises.readFile('contracts.json', 'utf-8');
		let dataParse = JSON.parse(data.toString());

		const oracleFactory = (new ethers.ContractFactory(
			OracleArtifact.abi,
			OracleArtifact.bytecode,
			signer[0]
		) as any) as OracleFactory;

		const uwuPolicy = ((await ethers.getContractAt(
			UwUPolicyArtifact.abi,
			dataParse['uwuPolicy'],
			signer[0]
		)) as any) as UwUPolicy;

		const oracle = await oracleFactory.deploy(
			dataParse['factory'],
			dataParse['uwu'],
			dataParse['busd'],
			dataParse['uwuPolicy']
		);

		await uwuPolicy.setOracle(oracle.address);
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
