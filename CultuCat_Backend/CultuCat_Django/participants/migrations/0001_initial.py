# Generated by Django 5.1.7 on 2025-04-19 19:32

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('groups', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='Participant',
            fields=[
                ('idgroup', models.ForeignKey(db_column='idgroup', on_delete=django.db.models.deletion.CASCADE, primary_key=True, serialize=False, to='groups.group')),
                ('rol', models.CharField(choices=[('Administrador', 'Administrador'), ('Membre', 'Membre'), ('Creador', 'Creador')], default='Membre', max_length=15)),
            ],
            options={
                'db_table': 'participant',
                'managed': False,
            },
        ),
    ]
