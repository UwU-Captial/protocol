import { promises } from 'fs';

async function main() {
	let userData1 = await promises.readFile('snap1-scaled.json', 'utf-8');
	let userDataParse = JSON.parse(userData1.toString());

	let userData2 = await promises.readFile('snap2-scaled.json', 'utf-8');
	let userDataParse2 = JSON.parse(userData2.toString());

	let userData3 = await promises.readFile('snap3-scaled.json', 'utf-8');
	let userDataParse3 = JSON.parse(userData3.toString());

	const arr = [];

	for (let index = 0; index < userDataParse.length; index++) {
		const element = userDataParse[index];
		const element2 = userDataParse2[index];
		const element3 = userDataParse3[index];

		arr.push({ user: element.user, balance: element.balance + element2.balance + element3.balance });
	}

	let total = 0;

	for (let index = 0; index < arr.length; index++) {
		arr[index].balance = arr[index].balance / 10;
		total += arr[index].balance;
	}

	console.log(total);

	const dataStore1 = JSON.stringify(arr);
	await promises.writeFile('total-scaled-balance.json', dataStore1);

	console.log('JSON data is saved.');
}

main().then(() => process.exit(0)).catch((error) => {
	console.error(error);
	process.exit(1);
});
