const express = require('express');

module.exports = (rpc, conn) => {
	const router = new express.Router();

	const task_queue = '${QUIZ_NAME}_quiz_taskworker'; // for stuff that'll need ML, etc.
	const db_read_queue = '${QUIZ_NAME}_quiz_dbread'; // simple endpoints
	const db_write_queue = '${QUIZ_NAME}_quiz_dbwrite'; // simple endpoints

	const stdPosts = [
		{ path: '/createUser', method: 'generateUser', queue: db_write_queue },
		{ path: '/startExperiment', method: 'startExperiment', queue: task_queue },
		{ path: '/getStimuliForUser', method: 'getStimuliForUser', queue: db_read_queue },
		{ path: '/metaResponse', method: 'insertMetaResponse', queue: db_write_queue },
		{ path: '/stimulusResponse', method: 'insertStimulusResponse', queue: db_write_queue },
		{ path: '/endExperiment', method: 'endExperiment', queue: task_queue },
	];

	stdPosts.forEach(point =>
		router.post(point.path, (req, res, next) => {
			console.log(`${point.path} hit`);

			const rpcParams = {
				method: point.method,
				data: req.body,
				sessionId: req.session.id
			};

			rpc(conn, point.queue, rpcParams)
				.then(rpcRes => {
					console.log(`${point.path} response: ${rpcRes}`);
					res.send({ resData: rpcRes });
				})
				.catch(rpcErr => {
					console.log('Error in API getting RPC response:');
					console.log(rpcErr);
					res.status(500).send(rpcError);
				});
		})
	);

	return router;
};
