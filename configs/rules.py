BRIDGES = {
    'LOCAL_PARROT': [
            {'SYSTEM': 'PARROT' ,  'TS': 2, 'TGID': 9999,  'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'NONE', 'ON': [9999], 'OFF': [], 'RESET': []},
            {'SYSTEM': 'MASTER-001', 'TS': 2, 'TGID': 9999,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [9999],  'OFF': [0,1],  'RESET': []},
            {'SYSTEM': 'MASTER-002', 'TS': 2, 'TGID': 9999,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [9999],  'OFF': [0,1],  'RESET': []},
            {'SYSTEM': 'MASTER-003', 'TS': 2, 'TGID': 9999,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [9999],  'OFF': [0,1],  'RESET': []},
            {'SYSTEM': 'MASTER-004', 'TS': 2, 'TGID': 9999,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [9999],  'OFF': [0,1],  'RESET': []},
            {'SYSTEM': 'MASTER-005', 'TS': 2, 'TGID': 9999,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [9999],  'OFF': [0,1],  'RESET': []},
            {'SYSTEM': 'MASTER-006', 'TS': 2, 'TGID': 9999,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [9999],  'OFF': [0,1],  'RESET': []},
        ],
    'LOCAL_TGIF349': [
            {'SYSTEM': 'TGIF349',  'TS': 2, 'TGID': 349,   'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'NONE', 'ON': [349], 'OFF': [0,1], 'RESET': []},
            {'SYSTEM': 'MASTER-001', 'TS': 2, 'TGID': 349,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [349],  'OFF': [0,1],  'RESET': []},
            {'SYSTEM': 'MASTER-002', 'TS': 2, 'TGID': 349,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [349],  'OFF': [0,1],  'RESET': []},
            {'SYSTEM': 'MASTER-003', 'TS': 2, 'TGID': 349,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [349],  'OFF': [0,1],  'RESET': []},
            {'SYSTEM': 'MASTER-004', 'TS': 2, 'TGID': 349,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [349],  'OFF': [0,1],  'RESET': []},
            {'SYSTEM': 'MASTER-005', 'TS': 2, 'TGID': 349,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [349],  'OFF': [0,1],  'RESET': []},
            {'SYSTEM': 'MASTER-006', 'TS': 2, 'TGID': 349,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [349],  'OFF': [0,1],  'RESET': []},
        ],
    'XLX349C': [
            {'SYSTEM': 'TGIF349',  'TS': 2, 'TGID': 349,   'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'NONE', 'ON': [0,], 'OFF': [0,1], 'RESET': []},
            {'SYSTEM': 'XLX349C',  'TS': 2, 'TGID': 9,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'NONE', 'ON': [0,], 'OFF': [0,1], 'RESET': []},
        ],
    'XLX349D': [
            {'SYSTEM': 'PARROT' ,  'TS': 2, 'TGID': 9999,  'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'NONE', 'ON': [0,], 'OFF': [0,1], 'RESET': []},
            {'SYSTEM': 'XLX349D',  'TS': 2, 'TGID': 9,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'NONE', 'ON': [0,], 'OFF': [0,1], 'RESET': []},
        ]
}

'''
    'XLX349E': [
            {'SYSTEM': 'OBP-1' ,   'TS': 2, 'TGID': 3166218,  'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'NONE', 'ON': [0,], 'OFF': [0,1], 'RESET': []},
            {'SYSTEM': 'XLX349E',  'TS': 2, 'TGID': 9,        'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'NONE', 'ON': [0,], 'OFF': [0,1], 'RESET': []},
        ]
    'PARROT-TG9999': [
            {'SYSTEM': 'PARROT',   'TS': 2, 'TGID': 9999,  'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'NONE', 'ON': [],   'OFF': [],    'RESET': []},
            {'SYSTEM': 'MASTER-1', 'TS': 2, 'TGID': 9999,  'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'NONE', 'ON': [],   'OFF': [],    'RESET': []},
        ]
    'PRIVATE_TG': [
            {'SYSTEM': 'MASTER-1', 'TS': 2, 'TGID': 9,     'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE':'OFF',  'ON': [9],  'OFF': [55],  'RESET': []},
        ]
'''



if __name__ == '__main__':
    from pprint import pprint
    pprint(BRIDGES)
