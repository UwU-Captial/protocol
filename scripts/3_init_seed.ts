import { ethers } from 'hardhat';

import SeedArtifact from '../artifacts/contracts/Seed.sol/Seed.json';
import IUniswapV2PairArtifact from '../artifacts/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol/IUniswapV2Pair.json';
import { IUniswapV2Pair } from '../type/IUniswapV2Pair';

import { formatEther, parseEther } from 'ethers/lib/utils';
import { promises } from 'fs';
import { Seed } from '../type/Seed';
import { BigNumber } from 'ethers';

async function main() {
	const signer = await ethers.getSigners();
	const account = await signer[0].getAddress();

	try {
		let data = await promises.readFile('contracts.json', 'utf-8');
		let dataParse = JSON.parse(data.toString());

		const uwuDistribution = parseEther('20000');
		const seedCap = parseEther('1000000');
		const walletCapPercentage = 5;
		const scale = parseEther('1');
		const seedDuration = 60 * 10 * 1;
		const distributionTime = 60 * 10 * 1;

		const uniswapV2Pair = new ethers.Contract(
			dataParse['bnbBusdLp'],
			IUniswapV2PairArtifact.abi,
			signer[0]
		) as IUniswapV2Pair;
		const resData = await uniswapV2Pair.getReserves();
		let currentPrice: BigNumber;

		if ((await uniswapV2Pair.token0()) == dataParse['bnb']) {
			currentPrice = resData.reserve1.mul(scale).div(resData.reserve0);
		} else {
			currentPrice = resData.reserve0.mul(scale).div(resData.reserve1);
		}

		const bnbCap = seedCap.mul(scale).div(currentPrice);
		const walletCap = bnbCap.mul(walletCapPercentage).div(100);
		const tokenExchangeRate = uwuDistribution.mul(scale).div(bnbCap);

		console.log(
			formatEther(currentPrice),
			formatEther(bnbCap),
			formatEther(walletCap),
			formatEther(tokenExchangeRate)
		);

		const seed = ((await ethers.getContractAt(SeedArtifact.abi, dataParse['seed'], signer[0])) as any) as Seed;

		await seed.initialize(
			dataParse['uwu'],
			dataParse['bnb'],
			dataParse['busd'],
			dataParse['factory'],
			dataParse['router'],
			dataParse['uwuPolicy'],
			account,
			bnbCap,
			walletCap,
			currentPrice,
			tokenExchangeRate,
			seedDuration,
			distributionTime
		);
	} catch (error) {
		console.error(error);
	}
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
