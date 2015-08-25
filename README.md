#Logstash Interval Metric Mysql Output

This plugin is designed specifically to output logstash interval metric events to a MySql database. This was created with the intent of creating an HTTP endpoint to query the interval metric counts from. 

##Install
You install this plugin as you would install all logstash plugins. Here is a [guide](https://www.elastic.co/guide/en/logstash/current/_how_to_write_a_logstash_filter_plugin.html#_test_installation_3) Use the test installation 

##Notice

This plugin assumes your mysql database is already set up

##Config
immysql has a handful on configs

	-`host`: mysql host
	-`port`: mysql port
	-`username`: mysql username
	-`password`: mysql password
	-`database`: mysql database
	-`table`: mysql table under database
	-`match`: the regex of the counts you want to match `.count` by default
	-`json_counter`: a boolean indicating if the counter name is in json form. If True this plugin will treat add the counter's fields into the mysql database

##Example

Example 1

Mysql db:

```
mysql> CREATE DATABASE test_db

mysql> use test_db

mysql> CREATE table test (msg_interval BIGINT, counter VARCHAR(255), count BIGINT, bucket_start BIGINT, bucket_end BIGINT);

mysql> DESCRIBE test;
+--------------+--------------+------+-----+-------------------+-------+
| Field        | Type         | Null | Key | Default           | Extra |
+--------------+--------------+------+-----+-------------------+-------+
| msg_interval | bigint(20)   | YES  |     | NULL              |       |
| counter      | varchar(255) | YES  |     | NULL              |       |
| count        | varchar(255) | YES  |     | NULL              |       |
| bucket_start | bigint(20)   | YES  |     | NULL              |       |
| bucket_end   | bigint(20)   | YES  |     | NULL              |       |
+--------------+--------------+------+-----+-------------------+-------+
```

logstash config:

```
input{
	stdin{}
}
filter{
	intervalmetric{
		counter => ["%{message}"]
		add_tag => "im"
	}
}
output{
	if "im" in [tags]{
		immysql{
			database => "test_db"
			table => "test"
			json_counter => false
		}
	}
}
```

input:

```
$ hi
```

mysql:

```
mysql> SELECT * from test;

+--------------+---------+---------+--------------+------------+
| msg_interval | counter | count   | bucket_start | bucket_end |
+--------------+---------+---------+--------------+------------+
|   1440519340 | hi      | 1       | 1440519330   | 1440519340 |
+--------------+---------+---------+--------------+------------+
```


Example 2

```
mysql> CREATE table test2 (msg_interval BIGINT, counter VARCHAR(255), bucket_start BIGINT, bucket_end BIGINT, host VARCHAR(255), path VARCHAR(255));

mysql> ALTER TABLE test2 ADD COLUMN createtime timestamp DEFAULT current_timestamp;

mysql> DESCRIBE test2;
+--------------+--------------+------+-----+-------------------+-------+
| Field        | Type         | Null | Key | Default           | Extra |
+--------------+--------------+------+-----+-------------------+-------+
| msg_interval | bigint(20)   | YES  |     | NULL              |       |
| counter      | varchar(255) | YES  |     | NULL              |       |
| count        | varchar(255) | YES  |     | NULL              |       |
| bucket_start | bigint(20)   | YES  |     | NULL              |       |
| bucket_end   | bigint(20)   | YES  |     | NULL              |       |
| host         | varchar(255) | YES  |     | NULL              |       |
| path         | varchar(255) | YES  |     | NULL              |       |
| createtime   | timestamp    | NO   |     | CURRENT_TIMESTAMP |       |
+--------------+--------------+------+-----+-------------------+-------+
```


logstash config:

```
input{
	file{
        path => "/file/path/*"
        start_position => "beginning"
    }
}
filter{
	intervalmetric{
		counter => ['{"host":"%{host}", "path": "%{path}"}']
		add_tag => "im"
	}
}
output{
	if "im" in [tags]{
		immysql{
			database => "test_db"
			table => "test2"
			json_counter => true
		}
	}
}
```

input:

```
$ ECHO 'hi' >> /file/path/1.txt
```

mysql:

```
mysql> SELECT * from test2;

+--------------+-------------------------------------------------------+--------------+--------------+------------+-----------+------------------+----------------------+
| msg_interval | counter                                               | count        | bucket_start | bucket_end | host      | path             | createtime           |
+--------------+-------------------------------------------------------+--------------+--------------+------------+-----------+------------------+----------------------+
|   1440519360 | {"host":"localhost", "path": "/file/path/1.txt"}      | 1            | 1440519340   | 1440519350 | localhost | /file/path/1.txt | 2015-08-25 10:49:00  |
+--------------+-------------------------------------------------------+--------------+--------------+------------+-----------+------------------+----------------------+

```