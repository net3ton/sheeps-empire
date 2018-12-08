import re
import json
import redis
from gevent.pywsgi import WSGIServer
from gevent.server import StreamServer
from geventwebsocket.handler import WebSocketHandler

REG_INPUT = re.compile("name=([A-z0-9\-\_\.]*)&score=([0-9]*)")
COUNT_LEADERS = 14
MAX_PLAYERS = 0xFFFFFFFF

REDIS = redis.StrictRedis(host='localhost', port=6379, db=0)
REDIS_KEY = "sheepsempire"

print("sheeps empire server...")

def make_pkey(pid, name):
    return "%08X:%s" % (MAX_PLAYERS - pid, name)

def get_name_from_pkey(pkey):
    ind = pkey.find(":")
    if ind >= 0:
        return pkey[ind+1:]
    return pkey

def prepare_result(name, score):
    pid = REDIS.zcard(REDIS_KEY)
    pkey = make_pkey(pid, name)

    REDIS.zadd(REDIS_KEY, { pkey: score })
    REDIS.save()

    pos = REDIS.zrevrank(REDIS_KEY, pkey)
    countLeaders = COUNT_LEADERS

    around = []
    if pos >= countLeaders:
        around = REDIS.zrevrange(REDIS_KEY, pos-1, pos+1, withscores=True)
        countLeaders -= 4

    leaders = REDIS.zrevrange(REDIS_KEY, 0, countLeaders-1, withscores=True)

    # prepare
    data = {}
    data['pos'] = pos

    itemsLeaders = []
    for ind, (itemkey, itemscore) in enumerate(leaders):
        itemdata = {}
        itemdata['pos'] = ind
        itemdata['name'] = get_name_from_pkey(itemkey)
        itemdata['score'] = itemscore
        itemsLeaders.append(itemdata)

    itemsAround = []
    if around:
        pind = -1
        for ind, (itemkey, itemscore) in enumerate(around):
            if itemkey == pkey:
                pind = ind
                break

        if pind == -1:
            pind = len(around)
            around.append((pkey, score))

        for ind, (itemkey, itemscore) in enumerate(around):
            itemdata = {}
            itemdata['pos'] = pos + (ind - pind)
            itemdata['name'] = get_name_from_pkey(itemkey)
            itemdata['score'] = itemscore
            itemsAround.append(itemdata)

    data['leaders'] = itemsLeaders
    data['around'] = itemsAround
    return data


def proccess_query(query):
    pinfo = REG_INPUT.search(query)
    if pinfo:
        pname, pscore = pinfo.groups()
        pscoreInt = int(pscore)

        if len(pname) > 0 and pscoreInt > 0:
            result = prepare_result(pname, pscoreInt)
            return (json.dumps(result), True)

    empty = {}
    empty['pos'] = -1
    empty['leaders'] = []
    empty['around'] = []
    return (json.dumps(empty), False)


def httpserver(env, start_response):
    pinfo = ""
    #if 'QUERY_STRING' in env:
    #    pinfo = env['QUERY_STRING']
    if 'wsgi.input' in env:
        pinfo = env['wsgi.input'].read()

    print(pinfo)
    response, result = proccess_query(pinfo)
    header = [('Content-Type', 'text/html'), ('Access-Control-Allow-Origin', '*')]

    if result:
        start_response('200 OK', header)
    else:
        start_response('404 Not Found', header)
    return response


def webserver(env, start_response):
    ws = env['wsgi.websocket']
    pinfo = ws.receive()
    if pinfo:
        response, result = proccess_query(pinfo)
        ws.send(response)
    return []

KEY = '/etc/letsencrypt/live/spacecows.ga/privkey.pem'
CERT = '/etc/letsencrypt/live/spacecows.ga/fullchain.pem'

WSGIServer(('0.0.0.0', 620), httpserver, keyfile=KEY, certfile=CERT).serve_forever()
#WSGIServer(('0.0.0.0', 620), webserver, handler_class=WebSocketHandler, keyfile=KEY, certfile=CERT).serve_forever()
