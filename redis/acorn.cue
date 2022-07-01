import "text/tabwriter"

import "list"

// prevents collision when using in token secrets
args: {
	deploy: {
		// Redis replicas per leader. Default (0).
		replicas: int | *0

		// Redis leader count. Setting this value 3 and above will configure Redis cluster. Default(1)
		leaders: int | *1

		// User provided configuration for leader and cluster servers
		leaderConfig: {}

		// User provided configuration for leader and cluster servers
		followerConfig: {}
	}
	build: {
		leaders: int | *2
	}
}

// Leaders
for l in list.Range(0, args.deploy.leaders, 1) {
	// Followers
	for f in list.Range(0, args.deploy.replicas+1, 1) {
		containers: {
			"redis-\(l)-\(f)": {
				image: "redis:7-alpine"
				cmd: ["/etc/redis/6379.conf"]
				if args.deploy.leaders > 1 {
					ports: "16379:16379/tcp"
				}
				expose: "6379:6379/tcp"
				env: {
					"REDISCLI_AUTH": "secret://redis-auth/token"
				}
				if args.deploy.leaders > 1 || f == 0 {
					files: {
						"/etc/redis/6379.conf": "secret://redis-leader-config/template"
					}
				}
				if args.deploy.leaders == 1 && f > 0 {
					files: {
						"/etc/redis/6379.conf": "secret://redis-follower-config/template"
					}
				}
				dirs: {
					"/data":          "volume://redis-data-dir-\(l)-\(f)"
					"/acorn/scripts": "./scripts"
				}
				probes: [
					{
						type:                "readiness"
						initialDelaySeconds: 5
						periodSeconds:       5
						timeoutSeconds:      2
						successThreshold:    1
						failureThreshold:    5
						exec: command: ["/bin/sh", "/acorn/scripts/redis-ping-local-readiness.sh", "1"]
					},
					{
						type:                "liveness"
						initialDelaySeconds: 5
						periodSeconds:       5
						timeoutSeconds:      6
						successThreshold:    1
						failureThreshold:    5
						exec: command: ["/bin/sh", "/acorn/scripts/redis-ping-local-liveness.sh", "5"]
					},
				]
			}
		}

		volumes: "redis-data-dir-\(l)-\(f)": accessModes: ["readWriteOnce"]
	}
}

secrets: {
	"redis-auth": {
		type: "token"
		params: length: 32
	}
	"redis-leader-config": {
		type: "template"
		data: template: tabwriter.Write([ for i, v in leaderConfigTemplate {"\(i) \(v)"}])
	}
	if args.deploy.replicas != 0 {
		"redis-follower-config": {
			type: "template"
			data: template: tabwriter.Write([ for i, v in followerConfigTemplate {"\(i) \(v)"}])
		}
	}

	// Provides user a target to bind in secret data
	"user-secret-data": type: "opaque"
}

if args.deploy.leaders > 1 || args.build.leaders > 1 {
	jobs: {
		"redis-init-cluster": {
			image: "redis:7-alpine"
			env: {
				"REDISCLI_AUTH": "secret://redis-auth/token"
			}
			dirs: {
				"/acorn/scripts": "./scripts"
			}
			cmd: "sleep 3600"
			//cmd: [
			//"/acorn/scripts/cluster-init-script.sh",
			//"\(args.deploy.leaders)",
			//"\(args.deploy.replicas)",
			//"\(localData.serverCount)",
			//]
		}
	}
	localData: redis:
		leaderConfig: {
			"cluster-enabled":      "yes"
			"cluster-config-file":  "nodes.conf"
			"cluster-node-timeout": int | *5000
			appendonly:             "yes"
		}
}

let leaderConfigTemplate = localData.redis.commonConfig & localData.redis.leaderConfig & args.deploy.leaderConfig
let followerConfigTemplate = localData.redis.commonConfig & localData.redis.followerConfig & args.deploy.followerConfig
localData: {
	redis: {
		commonConfig: {
			requirepass: "${secret://redis-auth/token}"
			masterauth:  "${secret://redis-auth/token}"
			port:        6379
			dir:         "/data"
			"######":    " ROLE CONFIG ######"
		}
		leaderConfig: "tcp-keepalive": int | *60
		followerConfig: {...} | *{}
		if args.deploy.replicas != 0 {
			followerConfig: {
				slaveof:           "redis-0-0 6379"
				"slave-read-only": "yes"
			}
		}
	}
	serverCount: args.deploy.leaders + (args.deploy.leaders * args.deploy.replicas)
}
